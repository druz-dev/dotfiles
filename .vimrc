set number			"Number of current line
set relativenumber  "Relative line numbers
"set nocompatible    "Disable compatibility with vi
filetype on         "Filetype detection
filetype plugin on  "Enable plugins and load for detected filetype
filetype indent on  "Load indent file for detected file type
syntax on           "Syntax highlighting
set cursorline      "cursorline indicator
set cursorcolumn    "cursorcolumn indicator
highlight CursorLine ctermfg=None ctermbg=Black cterm=bold 
highlight CursorColumn ctermfg=None ctermbg=Black cterm=bold
highlight CursorLineNr term=bold cterm=None ctermfg=magenta
set shiftwidth=4    "Set shift width to 4 spaces
set tabstop=4       "set tab width to 4 spaces
"set expandtab       "use space characters instead of tab
set nobackup        "Disable backup of files
set nowrap          "Disable text-wrapping
set incsearch       "Highlight matching characters while searching
set ignorecase      "make searching non-case-sensitive
set smartcase       "Make search case-sensitive is input has capital letters
set showcmd         "
set showmode        "Show vim mode on last line
set showmatch       "Show matching words during a search
set hlsearch        "highlight when doing a search
set wildmenu        "Enable autocompletion when pressing tab in command mode  
set wildmode=list:longest "Behave like bash completion
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx,*.gif "Hide these files 
nnoremap <esc><esc> :noh<return>

