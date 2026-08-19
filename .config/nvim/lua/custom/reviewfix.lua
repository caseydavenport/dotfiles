-- Hands the pending review comments to Claude as a worklist.
local M = {}

local octoreview = require "custom.octoreview"
local claudeterm = require "custom.claudeterm"

local QUERY = [[
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviews(states: [PENDING], first: 1) {
        nodes {
          comments(first: 100) {
            nodes { path line originalLine startLine originalStartLine body }
          }
        }
      }
    }
  }
}
]]

local PREAMBLE = [[
These are review comments I left on my own PR, as a worklist. Work them in order.
For each one: edit the files on the checked-out branch to address it, then tell me
what you changed and wait for my confirmation before starting the next.
]]

---@param pr table
---@param comments table[]
---@return string
local function worklist(pr, comments)
  local lines = { PREAMBLE, string.format("%s#%d, %d comment(s):", pr.repo, pr.number, #comments), "" }
  for i, c in ipairs(comments) do
    local last = c.line or c.originalLine or 0
    local first = c.startLine or c.originalStartLine or last
    local where = first == last and tostring(last) or string.format("%d-%d", first, last)
    table.insert(lines, string.format("%d. %s:%s", i, c.path, where))
    for _, body in ipairs(vim.split(vim.trim(c.body), "\n")) do
      table.insert(lines, "   " .. body)
    end
    table.insert(lines, "")
  end
  return table.concat(lines, "\n")
end

---@param out table
---@return table[]?
local function decode(out)
  -- luanil keeps JSON nulls from arriving as userdata that `or` won't fall through.
  local ok, decoded = pcall(vim.json.decode, out.stdout, { luanil = { object = true, array = true } })
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  local reviews = vim.tbl_get(decoded, "data", "repository", "pullRequest", "reviews", "nodes")
  if not reviews or #reviews == 0 then
    return {}
  end
  return vim.tbl_get(reviews[1], "comments", "nodes") or {}
end

---Send every pending comment on the current review to Claude.
function M.send_pending()
  local review = octoreview.current_review()
  if not review then
    return
  end
  local pr = review.pull_request
  local utils = require "octo.utils"
  local owner, name = pr.repo:match "^([^/]+)/(.+)$"
  if not owner then
    utils.error("Could not parse repo from " .. tostring(pr.repo))
    return
  end

  local args = {
    "gh",
    "api",
    "graphql",
    "-f",
    "query=" .. QUERY,
    "-f",
    "owner=" .. owner,
    "-f",
    "name=" .. name,
    "-F",
    "number=" .. tostring(pr.number),
  }
  utils.info "Fetching pending comments ..."
  vim.system(args, { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        utils.error("Could not fetch the pending review: " .. (out.stderr or ""))
        return
      end
      local comments = decode(out)
      if not comments then
        utils.error "Could not parse the pending review"
        return
      end
      if #comments == 0 then
        utils.info "No pending review comments"
        return
      end
      claudeterm.send(worklist(pr, comments))
    end)
  end)
end

---Delete the comment on the current diff line, via the thread panel that owns it.
function M.delete_comment_here()
  if not octoreview.current_review() then
    return
  end
  require("octo.reviews.thread-panel").show_review_threads(true)
  vim.schedule(function()
    if not pcall(vim.cmd, "Octo comment delete") then
      require("octo.utils").error "No comment under the cursor"
    end
  end)
end

---Register the actions octo's mapping table looks up by name.
function M.setup()
  local mappings = require "octo.mappings"
  mappings.ai_address_comments = M.send_pending
  mappings.delete_comment_here = M.delete_comment_here
end

return M
