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

---Register the actions octo's mapping table looks up by name.
function M.setup()
  local mappings = require "octo.mappings"
  mappings.mark_viewed_and_next = M.mark_viewed_and_next
  mappings.open_review_in_browser = M.open_in_browser
  mappings.show_review_diff = M.show_diff
  mappings.show_review_overview = M.show_overview
  mappings.show_review_threads = M.show_threads
end

return M
