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

" Set 7 lines to the cursor - when moving vertically using j/k
set so=7

" Use wild menu
set wildmenu

" Ignore compiled files
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
set lbr
set tw=120

augroup vimrc_autocmds
	" Highlight long lines for python files.
	autocmd BufEnter *.py highlight OverLength ctermbg=white ctermfg=darkred guibg=#111111
	autocmd BufEnter *.py match OverLength /\%80v.\+/

	" Delete trailing whitespace on python files.
    " autocmd BufWrite *.py :call DeleteTrailingWS()
augroup END
