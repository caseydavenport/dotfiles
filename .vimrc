" be improved, required.
set nocompatible
filetype off

" Spell checking
set nospell
set spelllang=en
set spellfile=$HOME/repos/dotfiles/vim-spellfile-en.utf-8.add

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'Valloric/YouCompleteMe'
Plugin 'fatih/vim-go'
Plugin 'AndrewRadev/splitjoin.vim'
Plugin 'majutsushi/tagbar'
Plugin 'terryma/vim-expand-region'
Plugin 'scrooloose/nerdtree'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-rhubarb'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'itchyny/lightline.vim'
Plugin 'SirVer/ultisnips'

" All of your Plugins must be added before the following line
call vundle#end()	     " required
filetype plugin indent on    " required

" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

" Set textwidth, useful for comment reflowing using gq
set textwidth=150

" Always show the status line
set laststatus=2

" Set status line
" set statusline=%f%=%l,%c\ %P
" set statusline+=%-10.3n\                     " buffer number

" Set color scheme
color koehler

" Set syntax highlighting on
syntax on

" Line numbering
set nu

" Highlight search
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

" Delete trailing white space on save
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc

" Delete trailing white space on save
func! NavigationToggle()
	NERDTreeToggle
	TagbarToggle
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

" Show matching brackets when text indicator is over them
set showmatch

" How many tenths of a second to blink when matching brackets
set mat=5

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=50

" Line break on 120 characters
" set lbr
" set tw=120

" Execute Pathogen plugins
" execute pathogen#infect()
syntax on
filetype plugin indent on

" Toggle navigation tools. 
nnoremap <silent> <F1> :NERDTreeToggle<CR>
nnoremap <silent> <F2> :TagbarToggle<CR>
nnoremap <silent> <F9> :call NavigationToggle()<CR>

" yaml autocommands.
augroup vimrc_md_autocmds
	" autocmd BufWrite *.yaml :call DeleteTrailingWS()
augroup END


" Markdown autocommands.
augroup vimrc_md_autocmds
	" autocmd BufWrite *.md :call DeleteTrailingWS()
augroup END

" Golang autocommands.
"
" Configure github.com/projectcalico GoGuruScope properly.
autocmd BufRead /home/casey/repos/gopath/src/*.go
      \  let s:tmp = matchlist(expand('%:p'),
          \ '/home/casey/repos/gopath/src/\(github.com/projectcalico/[^/]\+\)')
      \| if len(s:tmp) > 1 |  exe 'silent :GoGuruScope ' . s:tmp[1] | endif
      \| unlet s:tmp

" Configure github.com/tigera GoGuruScope properly.
autocmd BufRead /home/casey/repos/gopath/src/*.go
      \  let s:tmp = matchlist(expand('%:p'),
          \ '/home/casey/repos/gopath/src/\(github.com/tigera/[^/]\+\)')
      \| if len(s:tmp) > 1 |  exe 'silent :GoGuruScope ' . s:tmp[1] | endif
      \| unlet s:tmp

" Python autocommands.
augroup vimrc_py_autocmds
	" Highlight long lines for python files.
	autocmd BufEnter *.py highlight OverLength ctermbg=white ctermfg=darkred guibg=#111111
	autocmd BufEnter *.py match OverLength /\%80v.\+/

	" Delete trailing whitespace on python files.
	" autocmd BufWrite *.py :call DeleteTrailingWS()
augroup END

" Golang vim-go mappings for running, building, testing.
au FileType go nmap <leader>r <Plug>(go-run)
au FileType go nmap <leader>b <Plug>(go-build)

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

" Show potential implementations of the function under the cursor.
au FileType go nmap <Leader>f <Plug>(go-callees)

" Show potential callers of the function under the cursor.
au FileType go nmap <Leader>c <Plug>(go-callers)

" Show type info for the word under cursor.
au FileType go nmap <Leader>i <Plug>(go-info)

" Rename the identifier under the cursor.
au FileType go nmap <Leader>e <Plug>(go-rename)

" Switch CWD to the directory of the open buffer.
map <leader>cd :cd %:p:h<cr>:pwd<cr>

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

" Use gopls.
let g:go_def_mode = 'gopls'
let g:go_info_mode = 'gopls'
let g:ycm_gopls_binary_path = '/home/casey/repos/gopath/bin/gopls'
let g:go_build_tags = 'fvtests'

" Use strict goformatting
" https://github.com/mvdan/gofumpt
let g:go_gopls_gofumpt=1

" Set fuzzy file search shortcut.
let g:ctrlp_map = '<c-f>'

" move among buffers with CTRL
map <C-J> :bnext<CR>
map <C-K> :bprev<CR>

" Set timeout appropriately so leader commands don't time out right away.
set timeout timeoutlen=2000 ttimeoutlen=2000

" Set hidden
set hidden

" Bad habits.
noremap <Up> <NOP>
noremap <Down> <NOP>
noremap <Left> <NOP>
noremap <Right> <NOP>

" Override the status line to be more visible.
highlight StatusLine ctermbg=black ctermfg=white

" Support for searching for the highlighted text
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>

""""""""""""
" Configure split / join plugin.
""""""""""""
let g:splitjoin_split_mapping = 'gS'

"""""""""""""
" Configure snippet insertion
"""""""""""""

" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<C-F>"
"let g:UltiSnipsJumpForwardTrigger="<C-J>"
"let g:UltiSnipsJumpBackwardTrigger="<C-K>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

" Fugitive Conflict Resolution
nnoremap <leader>gd :Gvdiff!<CR>
nnoremap gdt :diffget //2<CR>
nnoremap gdm :diffget //3<CR>
nnoremap <leader>w :Gwrite<CR>
