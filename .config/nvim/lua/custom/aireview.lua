-- Claude as a review first pass. Findings stay local until you promote them.
local M = {}

local octoreview = require "custom.octoreview"

local SIGN_NS = vim.api.nvim_create_namespace "ai_review_findings"
local MODEL = "sonnet"

local CONTRACT = [[
You are doing a first-pass code review. Use the calico-code-review skill.

Report ONLY findings you would raise in a real review and defend if challenged:
correctness bugs, data races, resource leaks, error paths that drop errors,
API or wire-compatibility breaks, security issues. No style, no naming, no
"consider adding a comment", no praise, no summary. If nothing meets that bar,
return an empty array. An empty array is a good answer.

Write your findings as a JSON array to the output path given in the prompt,
using the Write tool. That file is the deliverable; your chat reply is ignored.
When nothing meets the bar, write exactly [] to it.

[{"file":"path","line":123,"side":"RIGHT","severity":"high|medium","category":"short-slug","comment":"what is wrong and why it matters"}]

`line` is a line number in the new file for side RIGHT, the old file for LEFT.
`comment` is at most three sentences.
]]

---Local clone of a repo, so findings can be based on more than the diff.
---@param name_with_owner string
---@return string?
function M.local_checkout(name_with_owner)
  local path = vim.fn.expand "~/repos/gopath/src/github.com" .. "/" .. name_with_owner
  if vim.fn.isdirectory(path .. "/.git") == 1 then
    return path
  end
end

---@return string
local function store_dir()
  return vim.fn.stdpath "data" .. "/octo-findings"
end

---@param pr table
---@return string
local function store_path(pr)
  return string.format("%s/%s__%d.json", store_dir(), (pr.repo:gsub("/", "__")), pr.number)
end

---@param pr table
---@return table[]
function M.load(pr)
  local path = store_path(pr)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  return decoded.findings or {}
end

---@param pr table
---@param findings table[]
function M.save(pr, findings)
  vim.fn.mkdir(store_dir(), "p")
  local payload = vim.json.encode { findings = findings }
  vim.fn.writefile(vim.split(payload, "\n"), store_path(pr))
end

---Findings still awaiting a decision.
---@param pr table
---@return table[]
local function open_findings(pr)
  local out = {}
  for _, finding in ipairs(M.load(pr)) do
    if finding.state == "open" then
      table.insert(out, finding)
    end
  end
  return out
end

---Virtual text and signs for findings on the file currently in the diff.
function M.refresh_overlay()
  local review = octoreview.current_review()
  local win = octoreview.diff_win()
  if not review or not win then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_buf_clear_namespace(bufnr, SIGN_NS, 0, -1)

  local file = review.layout:get_current_file()
  if not file then
    return
  end
  local last = vim.api.nvim_buf_line_count(bufnr)
  for _, finding in ipairs(open_findings(review.pull_request)) do
    if finding.file == file.path then
      local line = octoreview.display_line(bufnr, finding.side or "RIGHT", finding.line)
      if line >= 1 and line <= last then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, SIGN_NS, line - 1, -1, {
          virt_text = { { "  ⟡ " .. finding.category, "OctoPurple" } },
          virt_text_pos = "eol",
          sign_text = "⟡",
          sign_hl_group = "OctoPurple",
        })
      end
    end
  end
end

---@param text string
---@return table[]?
local function parse_findings(text)
  local first = text:find "%["
  if not first then
    -- No array at all. The model answered in prose, which it does when it has
    -- nothing to report, so treat that as a clean pass rather than a failure.
    return {}
  end
  local last = text:reverse():find "%]"
  if not last then
    -- An array that never closed means a truncated reply, not a clean pass.
    return nil
  end
  local body = text:sub(first, #text - last + 1)
  local ok, decoded = pcall(vim.json.decode, body)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

---One file's section of a unified diff.
---@param diff string
---@param path string
---@return string
local function diff_for_file(diff, path)
  local chunks = {}
  local current
  for line in (diff .. "\n"):gmatch "(.-)\n" do
    if line:match "^diff %-%-git " then
      current = { line }
      table.insert(chunks, current)
    elseif current then
      table.insert(current, line)
    end
  end
  for _, chunk in ipairs(chunks) do
    if chunk[1]:find(path, 1, true) then
      return table.concat(chunk, "\n")
    end
  end
  return ""
end

---@param pr table
---@param diff string
---@param scope string
local function run_claude(pr, diff, scope)
  local utils = require "octo.utils"
  utils.info(string.format("Reviewing %s ...", scope))
  local out_path = vim.fn.tempname() .. ".json"
  -- --add-dir is variadic, so it must be followed by a flag, never the prompt.
  local args = { "claude", "-p", "--add-dir", vim.fs.dirname(out_path) }
  local checkout = M.local_checkout(pr.repo)
  if checkout then
    table.insert(args, checkout)
  end
  vim.list_extend(args, {
    "--output-format",
    "json",
    "--model",
    MODEL,
    "--permission-mode",
    "acceptEdits",
    "--append-system-prompt",
    CONTRACT,
    string.format("Review the diff on stdin. Write your findings to %s.", out_path),
  })
  vim.system(args, { stdin = diff, text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        utils.error("Claude failed: " .. (out.stderr or ""):sub(1, 200))
        return
      end
      local ok, envelope = pcall(vim.json.decode, out.stdout)
      if not ok or envelope.is_error then
        utils.error "Claude returned an error"
        return
      end
      local found
      if vim.fn.filereadable(out_path) == 1 then
        found = parse_findings(table.concat(vim.fn.readfile(out_path), "\n"))
        os.remove(out_path)
      else
        -- It answered without writing the file, so fall back to the reply text.
        found = parse_findings(envelope.result or "")
      end
      if not found then
        utils.error "Could not parse findings from the reply"
        return
      end
      M.merge(pr, found, scope)
      local cost = envelope.total_cost_usd and string.format(" ($%.2f)", envelope.total_cost_usd) or ""
      utils.info(string.format("%d finding(s) on %s%s", #found, scope, cost))
    end)
  end)
end

---Add new findings, keeping decisions already made on matching ones.
---@param pr table
---@param found table[]
---@param scope string
function M.merge(pr, found, scope)
  local existing = M.load(pr)
  local seen = {}
  for _, finding in ipairs(existing) do
    seen[string.format("%s:%d:%s", finding.file, finding.line, finding.category)] = true
  end
  for _, finding in ipairs(found) do
    local key = string.format("%s:%d:%s", finding.file or "", finding.line or 0, finding.category or "")
    if not seen[key] then
      finding.state = "open"
      table.insert(existing, finding)
    end
  end
  M.save(pr, existing)
  M.refresh_overlay()
end

---@param scope "file"|"pr"
function M.review(scope)
  local review = octoreview.current_review()
  if not review then
    return
  end
  local pr = review.pull_request
  local file = review.layout:get_current_file()
  if scope == "file" and not file then
    return
  end
  local utils = require "octo.utils"
  vim.system({ "gh", "pr", "diff", tostring(pr.number), "-R", pr.repo }, { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 or out.stdout == "" then
        utils.error "Could not fetch the PR diff"
        return
      end
      if scope == "file" then
        local chunk = diff_for_file(out.stdout, file.path)
        if chunk == "" then
          utils.error("No diff found for " .. file.path)
          return
        end
        run_claude(pr, chunk, file.path)
      else
        run_claude(pr, out.stdout, string.format("%s#%d", pr.repo:gsub("^[^/]+/", ""), pr.number))
      end
    end)
  end)
end

---@param finding table
---@param state string
local function set_state(pr, finding, state)
  local all = M.load(pr)
  for _, other in ipairs(all) do
    if other.file == finding.file and other.line == finding.line and other.category == finding.category then
      other.state = state
    end
  end
  M.save(pr, all)
  M.refresh_overlay()
end

---Jump to a finding and open octo's comment buffer prefilled with its text.
---@param review table
---@param finding table
local function promote(review, finding)
  local layout = review.layout
  for _, file in ipairs(layout.files) do
    if file.path == finding.file then
      layout:set_current_file(file)
      break
    end
  end
  local win = octoreview.diff_win()
  if not win then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(win)
  local line = octoreview.display_line(bufnr, finding.side or "RIGHT", finding.line)
  pcall(vim.api.nvim_win_set_cursor, win, { math.min(line, vim.api.nvim_buf_line_count(bufnr)), 0 })
  set_state(review.pull_request, finding, "promoted")

  -- Octo derives the diff position from the cursor, so let it build the comment.
  require("octo.mappings").add_review_comment()
  vim.schedule(function()
    local text = vim.split(finding.comment, "\n")
    pcall(vim.api.nvim_buf_set_lines, vim.api.nvim_get_current_buf(), 0, -1, false, text)
  end)
end

---@param review table
---@param finding table
local function jump(review, finding)
  local layout = review.layout
  for _, file in ipairs(layout.files) do
    if file.path == finding.file then
      layout:set_current_file(file)
      break
    end
  end
  local win = octoreview.diff_win()
  if win then
    local bufnr = vim.api.nvim_win_get_buf(win)
    local line = octoreview.display_line(bufnr, finding.side or "RIGHT", finding.line)
    pcall(vim.api.nvim_win_set_cursor, win, { math.min(line, vim.api.nvim_buf_line_count(bufnr)), 0 })
    vim.cmd "normal! zz"
  end
end

---Picker over the findings still awaiting a decision.
function M.picker()
  local review = octoreview.current_review()
  if not review then
    return
  end
  local pr = review.pull_request
  local findings = open_findings(pr)
  if #findings == 0 then
    require("octo.utils").info "No open findings"
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
      { width = 6 },
      { width = 40 },
      { width = 16 },
      { remaining = true },
    },
  }

  local function entry_maker(finding)
    return {
      value = finding,
      ordinal = (finding.severity or "") .. " " .. finding.file .. " " .. finding.comment,
      display = function()
        return displayer {
          finding.severity or "",
          finding.file:gsub("^.*/", "") .. ":" .. finding.line,
          finding.category or "",
          vim.split(finding.comment, "\n")[1],
        }
      end,
    }
  end

  pickers
    .new({}, {
      prompt_title = string.format("Findings (%d) — <C-a> comment, <C-d> dismiss", #findings),
      finder = finders.new_table { results = findings, entry_maker = entry_maker },
      sorter = conf.generic_sorter {},
      previewer = false,
      attach_mappings = function(bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry then
            jump(review, entry.value)
          end
        end)
        map({ "i", "n" }, "<C-a>", function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry then
            promote(review, entry.value)
          end
        end)
        map({ "i", "n" }, "<C-d>", function()
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry then
            set_state(pr, entry.value, "dismissed")
          end
        end)
        return true
      end,
    })
    :find()
end

function M.setup()
  local mappings = require "octo.mappings"
  mappings.ai_review_file = function()
    M.review "file"
  end
  mappings.ai_review_pr = function()
    M.review "pr"
  end
  mappings.ai_findings = M.picker

  vim.api.nvim_create_autocmd({ "BufWinEnter", "TabEnter" }, {
    group = vim.api.nvim_create_augroup("AiReviewOverlay", { clear = true }),
    callback = function()
      pcall(M.refresh_overlay)
    end,
  })
end

return M
