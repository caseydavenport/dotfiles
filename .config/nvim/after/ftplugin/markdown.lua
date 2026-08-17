-- Markdown buffers: soft wrap, spell check, and render-markdown-friendly conceal.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.showbreak = "↪ "
vim.opt_local.colorcolumn = ""
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"
vim.opt_local.conceallevel = 2
vim.opt_local.textwidth = 0

-- Move by screen line, but keep 5j jumping five real lines.
local expr = { buffer = true, expr = true, silent = true }
vim.keymap.set("n", "j", function()
  return vim.v.count == 0 and "gj" or "j"
end, expr)
vim.keymap.set("n", "k", function()
  return vim.v.count == 0 and "gk" or "k"
end, expr)

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
end

map("<leader>mr", "<cmd>RenderMarkdown toggle<cr>", "Toggle in-buffer render")
map("<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", "Toggle browser preview")
map("<leader>ms", "<cmd>setlocal spell!<cr>", "Toggle spell check")
map("<leader>mf", function()
  require("conform").format({ async = true, lsp_fallback = false })
end, "Format with prettier")
