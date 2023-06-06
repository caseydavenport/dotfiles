-- Standard VIM configuraiton can go here.

-- Add a line-length delimiter.
vim.opt.colorcolumn = "160"

-- Disable swap files.
vim.opt.swapfile = false

-- Return to last edit position when opening files.
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Return to last edit position when opening files",
  command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]]}
)

-- autocmd Filetype go command! -bang A call go#alternate#Switch(<bang>0, 'edit')
vim.api.nvim_create_autocmd("Filetype", {
  desc = 'Switch between .go and _test.go files.',
  pattern = 'go',
  command = 'command! -bang A call go#alternate#Switch(<bang>0, \'edit\')'}
)

-- Trim trailing whitespace on save.
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})
