-- Custom octo review actions: viewed-state advance, view switching, browser.
local M = {}

---A live review, even when the cursor has left the review tabpage.
---@return table?
local function current_review()
  local reviews = require "octo.reviews"
  local review = reviews.get_current_review()
  if review then
    return review
  end
  for _, other in pairs(reviews.reviews) do
    local layout = other.layout
    if layout and layout.tabpage and vim.api.nvim_tabpage_is_valid(layout.tabpage) then
      return other
    end
  end
end

---Mark the current file viewed, then jump to the next unviewed one.
function M.mark_viewed_and_next()
  local layout = require("octo.reviews").get_current_layout()
  if not layout then
    return
  end
  local file = layout:get_current_file()
  if file and file.viewed_state ~= "VIEWED" then
    file:toggle_viewed()
  end
  layout:select_next_unviewed_file()
end

---Octo's own open_in_browser can't see a review buffer, so it opens the repo page.
function M.open_in_browser()
  local review = current_review()
  if not review then
    return
  end
  local host = require("octo.utils").get_remote_host() or "github.com"
  local pr = review.pull_request
  local url = string.format("https://%s/%s/pull/%d/files", host, pr.repo, pr.number)
  require("octo.navigation").open_in_browser_raw(url)
end

---Jump back to the review tabpage and put the cursor in the diff.
function M.show_diff()
  local review = current_review()
  if not review then
    return
  end
  local layout = review.layout
  if not (layout and layout.tabpage and vim.api.nvim_tabpage_is_valid(layout.tabpage)) then
    return
  end
  vim.api.nvim_set_current_tabpage(layout.tabpage)
  local win = layout.unified_winid or layout.right_winid
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

---Open the PR description and conversation in its own tab.
function M.show_overview()
  local review = current_review()
  if not review then
    return
  end
  local host = require("octo.utils").get_remote_host() or "github.com"
  local pr = review.pull_request
  local uri = string.format("octo://%s/%s/pull/%d", host, pr.repo, pr.number)
  -- `drop` reuses the tab already showing the buffer instead of stacking duplicates.
  vim.cmd("tab drop " .. vim.fn.fnameescape(uri))
end

---Open the comment threads attached to the current diff line.
function M.show_threads()
  require("octo.reviews.thread-panel").show_review_threads(true)
end

---Threads still wanting attention, ordered by file then line.
---@param review table
---@param include_resolved boolean
---@return table[]
local function open_threads(review, include_resolved)
  local file_order = {}
  for i, file in ipairs(review.layout.files) do
    file_order[file.path] = i
  end
  local out = {}
  for _, thread in pairs(review.threads) do
    local settled = thread.isResolved or thread.isOutdated
    if #thread.comments.nodes > 0 and (include_resolved or not settled) then
      table.insert(out, thread)
    end
  end
  table.sort(out, function(a, b)
    local fa = file_order[a.path] or math.huge
    local fb = file_order[b.path] or math.huge
    if fa ~= fb then
      return fa < fb
    end
    return (a.startLine or 0) < (b.startLine or 0)
  end)
  return out
end

---In a unified diff, thread lines are file lines on one side. Map to a screen line.
---@param bufnr integer
---@param thread table
---@return integer
local function display_line(bufnr, thread)
  local ok, line_map = pcall(vim.api.nvim_buf_get_var, bufnr, "octo_unified_line_map")
  if not ok or not line_map then
    return thread.startLine or 1
  end
  for line, entry in ipairs(line_map) do
    if entry.side == thread.diffSide and entry.line == thread.startLine then
      return line
    end
  end
  return thread.startLine or 1
end

---@param review table
---@param thread table
local function goto_thread(review, thread)
  local layout = review.layout
  for _, file in ipairs(layout.files) do
    if file.path == thread.path then
      -- Synchronous, and it focuses the diff window itself.
      layout:set_current_file(file)
      break
    end
  end
  local win = layout.unified_winid or layout.right_winid
  if win and vim.api.nvim_win_is_valid(win) then
    local bufnr = vim.api.nvim_win_get_buf(win)
    local target = display_line(bufnr, thread)
    local last = vim.api.nvim_buf_line_count(bufnr)
    pcall(vim.api.nvim_win_set_cursor, win, { math.min(target, last), 0 })
    vim.cmd "normal! zz"
  end
end

---Where the cursor sits in the thread ordering, as (file index, line).
---@param review table
---@return integer, integer
local function cursor_position(review)
  local layout = review.layout
  local file = layout:get_current_file()
  local idx = math.huge
  if file then
    for i, f in ipairs(layout.files) do
      if f.path == file.path then
        idx = i
        break
      end
    end
  end
  -- Outside the diff window the cursor line is meaningless, so anchor to the file.
  local win = layout.unified_winid or layout.right_winid
  if vim.api.nvim_get_current_win() ~= win then
    return idx, 0
  end
  return idx, vim.fn.line "."
end

---@param step integer
local function move_thread(step)
  local review = current_review()
  if not review then
    return
  end
  local threads = open_threads(review, false)
  if #threads == 0 then
    require("octo.utils").info "No open threads"
    return
  end
  local file_order = {}
  for i, f in ipairs(review.layout.files) do
    file_order[f.path] = i
  end
  local idx, line = cursor_position(review)
  local win = review.layout.unified_winid or review.layout.right_winid
  local bufnr = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)

  local function after(t)
    local ti = file_order[t.path] or math.huge
    if ti ~= idx then
      return step > 0 and ti > idx or step < 0 and ti < idx
    end
    -- Same file, so compare against the screen line the thread actually sits on.
    local tl = bufnr and display_line(bufnr, t) or (t.startLine or 0)
    return step > 0 and tl > line or step < 0 and tl < line
  end

  local found
  if step > 0 then
    for _, t in ipairs(threads) do
      if after(t) then
        found = t
        break
      end
    end
  else
    for i = #threads, 1, -1 do
      if after(threads[i]) then
        found = threads[i]
        break
      end
    end
  end
  -- Wrap, so repeated presses walk the whole PR.
  goto_thread(review, found or threads[step > 0 and 1 or #threads])
end

function M.next_thread()
  move_thread(1)
end

function M.prev_thread()
  move_thread(-1)
end

---@param thread table
---@return string
local function thread_summary(thread)
  local comment = thread.comments.nodes[1]
  local body = vim.split(comment.body or "", "\n")[1] or ""
  return vim.trim(body)
end

---Telescope picker over every open thread in the review.
---@param opts? { include_resolved?: boolean }
function M.thread_picker(opts)
  opts = opts or {}
  local review = current_review()
  if not review then
    return
  end
  local threads = open_threads(review, opts.include_resolved or false)
  if #threads == 0 then
    require("octo.utils").info "No open threads"
    return
  end

  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local entry_display = require "telescope.pickers.entry_display"
  local conf = require("telescope.config").values

  local displayer = entry_display.create {
    separator = "  ",
    items = {
      { width = 3 },
      { width = 44 },
      { width = 16 },
      { remaining = true },
    },
  }

  local function entry_maker(thread)
    local ref = thread.path:gsub("^.*/", "") .. ":" .. thread.startLine
    local author = thread.comments.nodes[1].author.login
    local mark = thread.isResolved and "✓" or (thread.isOutdated and "~" or "●")
    local summary = thread_summary(thread)
    return {
      value = thread,
      ordinal = thread.path .. " " .. author .. " " .. summary,
      display = function()
        return displayer { mark, ref, author, summary }
      end,
    }
  end

  pickers
    .new({}, {
      prompt_title = string.format("Review threads (%d)", #threads),
      finder = finders.new_table { results = threads, entry_maker = entry_maker },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry then
            goto_thread(review, entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

local CHECK_ICONS = { fail = "✗", pending = "◌", cancel = "⊘", skipping = "-", pass = "✓" }
local CHECK_ORDER = { fail = 1, pending = 2, cancel = 3, skipping = 4, pass = 5 }

---Checks for the PR under review. Covers Semaphore and Argo, which post as
---commit statuses rather than GitHub Actions runs.
function M.checks_picker()
  local review = current_review()
  if not review then
    return
  end
  local pr = review.pull_request
  local args = {
    "gh",
    "pr",
    "checks",
    tostring(pr.number),
    "-R",
    pr.repo,
    "--json",
    "bucket,name,state,link,description,workflow",
  }
  require("octo.utils").info "Fetching checks ..."
  vim.system(args, { text = true }, function(out)
    -- gh exits non-zero when checks are failing or pending, so parse regardless.
    local ok, checks = pcall(vim.json.decode, out.stdout ~= "" and out.stdout or "[]")
    vim.schedule(function()
      if not ok or #checks == 0 then
        require("octo.utils").info "No checks reported"
        return
      end
      table.sort(checks, function(a, b)
        local oa = CHECK_ORDER[a.bucket] or 9
        local ob = CHECK_ORDER[b.bucket] or 9
        if oa ~= ob then
          return oa < ob
        end
        return a.name < b.name
      end)
      M.show_checks(pr, checks)
    end)
  end)
end

---@param pr table
---@param checks table[]
function M.show_checks(pr, checks)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local entry_display = require "telescope.pickers.entry_display"
  local conf = require("telescope.config").values

  local displayer = entry_display.create {
    separator = "  ",
    items = {
      { width = 2 },
      { width = 40 },
      { remaining = true },
    },
  }

  local failing = 0
  for _, check in ipairs(checks) do
    if check.bucket == "fail" then
      failing = failing + 1
    end
  end

  local function entry_maker(check)
    return {
      value = check,
      ordinal = check.bucket .. " " .. check.name,
      display = function()
        return displayer {
          CHECK_ICONS[check.bucket] or "?",
          check.name,
          check.description or "",
        }
      end,
    }
  end

  pickers
    .new({}, {
      prompt_title = string.format("%s#%d checks (%d failing)", pr.repo:gsub("^[^/]+/", ""), pr.number, failing),
      finder = finders.new_table { results = checks, entry_maker = entry_maker },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry and entry.value.link ~= "" then
            require("octo.navigation").open_in_browser_raw(entry.value.link)
          end
        end)
        return true
      end,
    })
    :find()
end

---@param review table
---@return string
local function format_winbar(review)
  local layout = review.layout
  local pr = review.pull_request
  local total = #layout.files
  local unviewed = 0
  for _, file in ipairs(layout.files) do
    if file.viewed_state ~= "VIEWED" then
      unviewed = unviewed + 1
    end
  end
  local threads = #open_threads(review, false)

  local parts = {
    string.format("%%#OctoBlue#%s#%d%%*", pr.repo:gsub("^[^/]+/", ""), pr.number),
    string.format("file %d/%d", layout.selected_file_idx, total),
  }
  if unviewed > 0 then
    table.insert(parts, string.format("%%#OctoYellow#%d unviewed%%*", unviewed))
  else
    table.insert(parts, "%#OctoGreen#all viewed%*")
  end
  if threads > 0 then
    table.insert(parts, string.format("%%#OctoRed#%d open%%*", threads))
  end
  return " " .. table.concat(parts, "  ·  ")
end

---Winbar contents for the review diff. Re-evaluated on every redraw.
---@return string
function M.winbar()
  local review = require("octo.reviews").get_current_review()
  if not review or not review.layout then
    return ""
  end
  local ok, out = pcall(format_winbar, review)
  return ok and out or ""
end

---Show the winbar on the diff window of the review in this tabpage.
local function attach_winbar()
  local reviews = require "octo.reviews"
  local review = reviews.reviews[tostring(vim.api.nvim_get_current_tabpage())]
  if not (review and review.layout) then
    return
  end
  local win = review.layout.unified_winid or review.layout.right_winid
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].winbar = "%{%v:lua.require'custom.octoreview'.winbar()%}"
  end
end

---Register the actions octo's mapping table looks up by name.
function M.setup()
  local mappings = require "octo.mappings"
  mappings.mark_viewed_and_next = M.mark_viewed_and_next
  mappings.open_review_in_browser = M.open_in_browser
  mappings.show_review_diff = M.show_diff
  mappings.show_review_overview = M.show_overview
  mappings.show_review_threads = M.show_threads
  mappings.next_open_thread = M.next_thread
  mappings.prev_open_thread = M.prev_thread
  mappings.list_review_threads = function()
    M.thread_picker()
  end
  mappings.list_all_review_threads = function()
    M.thread_picker { include_resolved = true }
  end
  mappings.list_pr_checks = M.checks_picker

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "TabEnter" }, {
    group = vim.api.nvim_create_augroup("OctoReviewWinbar", { clear = true }),
    callback = attach_winbar,
  })
end

return M
