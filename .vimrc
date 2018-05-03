" Plugin directives for vim-plug.
call plug#begin()
" Plug 'ctrlpvim/ctrlp.vim'
" Plug 'Valloric/YouCompleteMe'
call plug#end()


" Set status line
set statusline=%f%=%l,%c\ %P

" Set color
color koehler

" Line numbering
set nu

" Higlhight search
set hls

" Configure auto-completion menu
set completeopt=longest,menuone

" Set enter key as select popup item
inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"                                                                                                                         
set backspace=indent,eol,start

" Set 7 lines to the cursor - when moving vertically using j/k
set so=7

" Use wildmenu for command completion.
set wildmenu

" Ignore compiled files in wildmenu.
set wildignore=*.o,*~,*.pyc

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases 
set smartcase

" Makes search act like search in modern browsers
set incsearch

" Always have item selected
inoremap <expr> <C-n> pumvisible() ? '<C-n>' : '<C-n><C-r>=pumvisible() ? "\<lt>Down>" : ""<CR>'
inoremap <expr> <M-,> pumvisible() ? '<C-n>' : '<C-x><C-o><C-n><C-p><C-r>=pumvisible() ? "\<lt>Down>" : ""<CR>'

" Delete trailing white space on save
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc

" Return to last edit position when opening files (You want this!)
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

" Python spacing 
autocmd BufRead *.py set expandtab
autocmd BufRead *.py set shiftwidth=4
autocmd BufRead *.py set tabstop=4

" lua spacing
autocmd BufRead *.lua set expandtab
autocmd BufRead *.lua set shiftwidth=2 
autocmd BufRead *.lua set tabstop=2 
autocmd BufRead *.yml set expandtab

" Be smart when using tabs 
set smarttab

" NO SWAP FILE
set noswapfile

" Auto indent on new line
set nosmartindent 
filetype plugin indent on

" Set syntax highlighting on
syntax on

" Show matching brackets when text indicator is over them
set showmatch

" How many tenths of a second to blink when matching brackets
set mat=5

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=50

" Linebreak on 120 characters
" set lbr
" set tw=120

" Execute Pathogen plugins
execute pathogen#infect()
syntax on
filetype plugin indent on

" For tagbar, set F9 as the toggle button.
nnoremap <silent> <F9> :TagbarToggle<CR>

" yaml autocommands.
augroup vimrc_md_autocmds
	" Delete trailing whitespace on go files.
        autocmd BufWrite *.yaml :call DeleteTrailingWS()
augroup END


" Markdown autocommands.
augroup vimrc_md_autocmds
	" Delete trailing whitespace on go files.
        autocmd BufWrite *.md :call DeleteTrailingWS()
augroup END

" Golang autocommands.
augroup vimrc_go_autocmds
augroup END

" Python autocommands.
augroup vimrc_py_autocmds
	" Highlight long lines for python files.
	autocmd BufEnter *.py highlight OverLength ctermbg=white ctermfg=darkred guibg=#111111
	autocmd BufEnter *.py match OverLength /\%80v.\+/

	" Delete trailing whitespace on python files.
        autocmd BufWrite *.py :call DeleteTrailingWS()
augroup END

" Golang vim-go mappings for running, building, testing.
au FileType go nmap <leader>r <Plug>(go-run)
au FileType go nmap <leader>b <Plug>(go-build)
au FileType go nmap <leader>t <Plug>(go-test)
au FileType go nmap <leader>c <Plug>(go-coverage)

" Golang vim-go mappings for opening targets in various places.
au FileType go nmap <Leader>df <Plug>(go-def)
au FileType go nmap <Leader>ds <Plug>(go-def-split)
au FileType go nmap <Leader>dv <Plug>(go-def-vertical)
au FileType go nmap <Leader>dt <Plug>(go-def-tab)

" Golang vim-go mappings for docs
au FileType go nmap <Leader>g <Plug>(go-doc)
au FileType go nmap <Leader>gv <Plug>(go-doc-vertical)

" Show interfaces which are implemented by the type under cursor.
au FileType go nmap <Leader>s <Plug>(go-implements)

" Show type info for the word under cursor.
au FileType go nmap <Leader>i <Plug>(go-info)

" Rename the identifier under the cursor.
au FileType go nmap <Leader>e <Plug>(go-rename)

" Alias some GoAlternate variations to new shorter commands.
autocmd Filetype go command! -bang A call go#alternate#Switch(<bang>0, 'edit')
autocmd Filetype go command! -bang AV call go#alternate#Switch(<bang>0, 'vsplit')
autocmd Filetype go command! -bang AS call go#alternate#Switch(<bang>0, 'split')
autocmd Filetype go command! -bang AT call go#alternate#Switch(<bang>0, 'tabe')

" Alias the GoDecls and GoDeclsDir commands so they're shorter.
:command GD GoDecls
:command GDD GoDeclsDir

" Enable Golang syntax highlighting
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_fields = 1
let g:go_highlight_types = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1

" move among buffers with CTRL
map <C-J> :bnext<CR>
map <C-K> :bprev<CR>

" Set timeout appropriately so leader commands don't time out right away.
set timeout timeoutlen=2000 ttimeoutlen=2000
