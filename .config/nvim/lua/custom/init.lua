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

----------------------------------------------------------------
-- Remap keys
----------------------------------------------------------------
local function map(mode, lhs, rhs, opts)
  local options = { noremap=true, silent=true }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end


-- " Golang vim-go mappings for opening targets in various places.
-- au FileType go nmap <Leader>ds <Plug>(go-def-split)
vim.keymap.set('n', '<Leader>ds', '<Plug>(go-def-split)')
-- au FileType go nmap <Leader>dv <Plug>(go-def-vertical)
vim.keymap.set('n', '<Leader>dv', '<Plug>(go-def-vertical)')

-- Remap buffer navigation.
map('n', '<A-j>', ':bnext<CR>')
map('n', '<A-k>', ':bprev<CR>')
