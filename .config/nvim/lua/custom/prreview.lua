-- Telescope picker over review-worthy PRs that opens an octo review directly.
local M = {}

local GOPATH_SRC = vim.fn.expand "~/repos/gopath/src/github.com"

-- Each source contributes a tag shown in the picker.
local SOURCES = {
  { tag = "review", search = "--review-requested=@me" },
  { tag = "assigned", search = "--assignee=@me" },
  { tag = "mine", search = "--author=@me" },
}

local JSON_FIELDS = "number,title,repository,author,updatedAt,isDraft,url"

-- Bot accounts GitHub reports as regular users. Backport and sync PR openers.
M.bot_logins = {
  ["marvin-tigera"] = true,
}

-- Repos pinned to the front of the tab bar. The rest follow alphabetically.
M.repo_order = {
  "projectcalico/calico",
  "tigera/calico-private",
  "tigera/operator",
}

vim.api.nvim_set_hl(0, "PRReviewTab", { link = "Comment", default = true })
vim.api.nvim_set_hl(0, "PRReviewTabActive", { link = "Search", default = true })

local BAR_NS = vim.api.nvim_create_namespace "prreview_tabs"

---@param pr table
---@return boolean
local function is_bot(pr)
  local login = pr.author and pr.author.login or ""
  return pr.author.type == "Bot" or M.bot_logins[login] or login:match "%[bot%]$" ~= nil
end

---Local checkout for a repo, or nil if it isn't cloned.
---@param name_with_owner string
---@return string?
local function local_checkout(name_with_owner)
  local path = GOPATH_SRC .. "/" .. name_with_owner
  if vim.fn.isdirectory(path .. "/.git") == 1 then
    return path
  end
end

---@param limit integer
---@param cb fun(prs: table[])
local function fetch_prs(limit, cb)
  local by_key = {}
  local order = {}
  local pending = #SOURCES

  local function done()
    pending = pending - 1
    if pending > 0 then
      return
    end
    local prs = {}
    for _, key in ipairs(order) do
      table.insert(prs, by_key[key])
    end
    table.sort(prs, function(a, b)
      return a.updatedAt > b.updatedAt
    end)
    vim.schedule(function()
      cb(prs)
    end)
  end

  for _, source in ipairs(SOURCES) do
    local args = {
      "gh",
      "search",
      "prs",
      source.search,
      "--state=open",
      "--limit=" .. limit,
      "--json=" .. JSON_FIELDS,
    }
    vim.system(args, { text = true }, function(out)
      if out.code == 0 and out.stdout ~= "" then
        local ok, decoded = pcall(vim.json.decode, out.stdout)
        if ok then
          for _, pr in ipairs(decoded) do
            local key = pr.repository.nameWithOwner .. "#" .. pr.number
            local existing = by_key[key]
            if existing then
              table.insert(existing.tags, source.tag)
            else
              pr.tags = { source.tag }
              pr.repo = pr.repository.nameWithOwner
              by_key[key] = pr
              table.insert(order, key)
            end
          end
        end
      end
      done()
    end)
  end
end

---Fetch just enough of a PR to build octo's PullRequest model.
---@param repo string
---@param number integer
---@param cb fun(pull_request: table)
local function resolve_pull_request(repo, number, cb)
  local gh = require "octo.gh"
  local PullRequest = require "octo.model.pull-request"
  local owner, name = require("octo.utils").split_repo(repo)

  local query = [[
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          id
          baseRefName
          baseRefOid
          headRefName
          headRefOid
          headRepository { nameWithOwner }
          files(first: 100) {
            nodes {
              path
              viewerViewedState
            }
          }
        }
      }
    }
  ]]

  gh.api.graphql {
    query = query,
    F = { owner = owner, name = name, number = number },
    jq = ".data.repository.pullRequest",
    opts = {
      cb = gh.create_callback {
        success = function(output)
          local obj = vim.json.decode(output)
          PullRequest.create_with_merge_base({
            repo = repo,
            head_repo = obj.headRepository.nameWithOwner,
            head_ref_name = obj.headRefName,
            number = number,
            id = obj.id,
          }, obj, cb)
        end,
      },
    },
  }
end

---@param entry table
---@param mode "review"|"browse"
function M.open(entry, mode)
  local reviews = require "octo.reviews"
  local utils = require "octo.utils"

  -- Global cd, not lcd: octo resolves blobs against cwd from a fresh tab.
  local checkout = local_checkout(entry.repo)
  if checkout then
    vim.cmd.cd(checkout)
  else
    utils.info(entry.repo .. " is not cloned locally, diffing from the API")
  end

  utils.info(string.format("Opening %s#%d", entry.repo, entry.number))
  resolve_pull_request(entry.repo, entry.number, function(pull_request)
    local review = reviews.Review:new(pull_request)
    if mode == "browse" then
      review:browse()
    else
      review:start_or_resume()
    end
  end)
end

---@param opts table?
function M.picker(opts)
  opts = opts or {}
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local entry_display = require "telescope.pickers.entry_display"

  fetch_prs(opts.limit or 100, function(prs)
    if #prs == 0 then
      require("octo.utils").error "No open PRs found"
      return
    end

    local displayer = entry_display.create {
      separator = "  ",
      items = {
        { width = 10 },
        { width = 34 },
        { width = 18 },
        { remaining = true },
      },
    }

    -- Pinned repos first, then alphabetical. Order never shifts as filters change.
    local rank = {}
    for i, repo in ipairs(M.repo_order) do
      rank[repo] = i
    end

    local seen, repos = {}, {}
    for _, pr in ipairs(prs) do
      if not seen[pr.repo] then
        seen[pr.repo] = true
        table.insert(repos, pr.repo)
      end
    end
    -- Alphabetical on the label shown in the bar, not the owner-qualified name.
    table.sort(repos, function(a, b)
      local ra, rb = rank[a] or math.huge, rank[b] or math.huge
      if ra ~= rb then
        return ra < rb
      end
      return a:gsub("^[^/]+/", "") < b:gsub("^[^/]+/", "")
    end)

    local tabs = {
      { label = "assigned", tag = "assigned" },
      { label = "all" },
    }
    for _, repo in ipairs(repos) do
      table.insert(tabs, { label = repo:gsub("^[^/]+/", ""), repo = repo })
    end

    local tab = 1
    local show_bots = opts.show_bots or false

    ---@param pr table
    ---@param index integer
    ---@return boolean
    local function matches(pr, index)
      local this = tabs[index]
      if this.repo and pr.repo ~= this.repo then
        return false
      end
      if this.tag and not vim.tbl_contains(pr.tags, this.tag) then
        return false
      end
      return show_bots or not is_bot(pr)
    end

    ---@param index integer
    ---@return table[]
    local function filtered(index)
      local out = {}
      for _, pr in ipairs(prs) do
        if matches(pr, index) then
          table.insert(out, pr)
        end
      end
      return out
    end

    local function entry_maker(pr)
      local tags = table.concat(pr.tags, ",")
      local ref = pr.repo:gsub("^[^/]+/", "") .. "#" .. pr.number
      local title = pr.isDraft and ("[draft] " .. pr.title) or pr.title
      return {
        value = pr,
        repo = pr.repo,
        number = pr.number,
        ordinal = tags .. " " .. pr.repo .. " " .. pr.title .. " " .. pr.author.login,
        display = function()
          return displayer {
            tags,
            ref,
            pr.author.login,
            title,
          }
        end,
      }
    end

    local function make_finder()
      return finders.new_table {
        results = filtered(tab),
        entry_maker = entry_maker,
      }
    end

    local function prompt_title()
      local suffix = show_bots and ", bots shown" or ""
      return string.format("Review PRs (%d%s)", #filtered(tab), suffix)
    end

    ---Tab bar text plus the active segment's byte range, windowed to fit width.
    ---@param width integer
    ---@return string text
    ---@return integer hl_start
    ---@return integer hl_end
    local function tab_bar(width)
      local segments = {}
      for i in ipairs(tabs) do
        segments[i] = string.format(" %s %d ", tabs[i].label, #filtered(i))
      end

      local first, last = 1, #tabs
      local total = 0
      for _, seg in ipairs(segments) do
        total = total + #seg
      end

      local lead, trail = "", ""
      if total > width then
        -- Something gets cut, so reserve room for both "< " and " >" markers.
        local budget = width - 4
        if #segments[tab] > budget then
          local clipped = segments[tab]:sub(1, math.max(width, 1))
          return clipped, 0, #clipped
        end

        -- Grow outward from the active tab until the next segment won't fit.
        first, last = tab, tab
        local used = #segments[tab]
        while true do
          local grew = false
          if last < #segments and used + #segments[last + 1] <= budget then
            last = last + 1
            used = used + #segments[last]
            grew = true
          end
          if first > 1 and used + #segments[first - 1] <= budget then
            first = first - 1
            used = used + #segments[first]
            grew = true
          end
          if not grew then
            break
          end
        end

        lead = first > 1 and "< " or ""
        trail = last < #segments and " >" or ""
      end

      local hl_start = #lead
      for i = first, tab - 1 do
        hl_start = hl_start + #segments[i]
      end
      return lead .. table.concat(segments, "", first, last) .. trail, hl_start, hl_start + #segments[tab]
    end

    local bar_buf, bar_win

    ---Span of the whole picker, so the bar can sit above it at full width.
    ---@param picker table
    ---@return integer? row, integer? col, integer? width
    local function picker_span(picker)
      local prompt = picker.prompt_win
      if not prompt or not vim.api.nvim_win_is_valid(prompt) then
        return
      end
      local pos = vim.api.nvim_win_get_position(prompt)
      local right = pos[2] + vim.api.nvim_win_get_width(prompt)
      local preview = picker.preview_win
      if preview and vim.api.nvim_win_is_valid(preview) then
        local ppos = vim.api.nvim_win_get_position(preview)
        right = math.max(right, ppos[2] + vim.api.nvim_win_get_width(preview))
      end
      return pos[1], pos[2], right - pos[2]
    end

    ---@param picker table
    local function draw_tab_bar(picker)
      local row, col, width = picker_span(picker)
      if not row or width < 4 then
        return
      end

      -- Sit above the prompt's top border, which occupies row - 1.
      local bar_row = math.max(row - 2, 0)
      local text, hl_start, hl_end = tab_bar(width)

      if not bar_buf or not vim.api.nvim_buf_is_valid(bar_buf) then
        bar_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[bar_buf].bufhidden = "wipe"
      end
      vim.api.nvim_buf_set_lines(bar_buf, 0, -1, false, { text })
      vim.api.nvim_buf_clear_namespace(bar_buf, BAR_NS, 0, -1)
      vim.api.nvim_buf_set_extmark(bar_buf, BAR_NS, 0, 0, {
        end_col = #text,
        hl_group = "PRReviewTab",
      })
      vim.api.nvim_buf_set_extmark(bar_buf, BAR_NS, 0, hl_start, {
        end_col = math.min(hl_end, #text),
        hl_group = "PRReviewTabActive",
      })

      local config = {
        relative = "editor",
        row = bar_row,
        col = col,
        width = width,
        height = 1,
        style = "minimal",
        zindex = 250,
      }
      if bar_win and vim.api.nvim_win_is_valid(bar_win) then
        vim.api.nvim_win_set_config(bar_win, config)
      else
        bar_win = vim.api.nvim_open_win(bar_buf, false, config)
        vim.wo[bar_win].winblend = 0
      end
    end

    local function close_tab_bar()
      if bar_win and vim.api.nvim_win_is_valid(bar_win) then
        vim.api.nvim_win_close(bar_win, true)
      end
      bar_win, bar_buf = nil, nil
    end

    ---@param picker table
    local function redraw(picker)
      picker:refresh(make_finder(), { reset_prompt = false })
      if picker.prompt_border then
        picker.prompt_border:change_title(prompt_title())
      end
      draw_tab_bar(picker)
    end

    local picker = pickers
      .new(opts, {
        prompt_title = prompt_title(),
        finder = make_finder(),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
          local function pick(mode)
            return function()
              local entry = action_state.get_selected_entry()
              actions.close(prompt_bufnr)
              if entry then
                M.open(entry.value, mode)
              end
            end
          end

          ---@param step integer
          local function cycle_tab(step)
            return function()
              tab = (tab - 1 + step) % #tabs + 1
              redraw(action_state.get_current_picker(prompt_bufnr))
            end
          end

          actions.select_default:replace(pick "review")
          map({ "i", "n" }, "<C-r>", pick "browse")
          map({ "i", "n" }, "<Tab>", cycle_tab(1))
          map({ "i", "n" }, "<S-Tab>", cycle_tab(-1))
          map({ "i", "n" }, "<C-j>", actions.move_selection_next)
          map({ "i", "n" }, "<C-k>", actions.move_selection_previous)
          map({ "i", "n" }, "<C-t>", function()
            show_bots = not show_bots
            redraw(action_state.get_current_picker(prompt_bufnr))
          end)
          map({ "i", "n" }, "<C-o>", function()
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if entry then
              vim.ui.open(entry.value.url)
            end
          end)
          vim.api.nvim_create_autocmd({ "BufWipeout", "BufLeave" }, {
            buffer = prompt_bufnr,
            once = true,
            callback = close_tab_bar,
          })
          return true
        end,
      })

    picker:find()

    -- Draw once the picker windows exist and can report their real geometry.
    vim.schedule(function()
      draw_tab_bar(picker)
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("ReviewPRs", function()
    M.picker()
  end, { desc = "Pick a PR and open its review" })
  vim.keymap.set("n", "<leader>rp", M.picker, { desc = "Pick a PR to review" })
end

return M
