-- Claude Code in a floating terminal, shared by anything that wants to talk to it.
local M = {}

local buf = nil
local win = nil
local job = nil

---@return table
local function win_opts()
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  return {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  }
end

---Show the float, starting a session only when there isn't one.
---@return boolean started true when a new claude session was launched
function M.open()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    win = vim.api.nvim_open_win(buf, true, win_opts())
    vim.cmd "startinsert"
    return false
  end

  buf = vim.api.nvim_create_buf(false, true)
  win = vim.api.nvim_open_win(buf, true, win_opts())
  job = vim.fn.termopen("claude", {
    on_exit = function()
      buf, win, job = nil, nil, nil
    end,
  })
  vim.cmd "startinsert"
  return true
end

function M.toggle()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, false)
    win = nil
    return
  end
  M.open()
end

---@param text string
local function paste(text)
  if not job then
    return
  end
  -- Bracketed paste keeps a multi-line prompt as one message instead of many.
  vim.fn.chansend(job, "\27[200~" .. text .. "\27[201~")
  vim.defer_fn(function()
    if job then
      vim.fn.chansend(job, "\r")
    end
  end, 100)
end

---Paste text into the session and submit it.
---@param text string
function M.send(text)
  local started = M.open()
  if not job then
    return false
  end
  -- A session that just launched isn't reading input yet.
  vim.defer_fn(function()
    paste(text)
  end, started and 2000 or 50)
  return true
end

return M
