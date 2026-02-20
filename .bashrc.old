#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
#alias normalvim='vim'
#alias vim='kitty @ set-spacing padding=0 && nvim && kitty @ set-spacing padding=10'
#alias nvim='kitty @ set-spacing padding=0 && nvim && kitty @ set-spacing padding=10'
alias vim='nvim'
function sfml() {
	INPUT=${1-main.cpp}
	OUTPUT=${2-a.out}
	g++ $INPUT -o $OUTPUT -Iusr/lib/include -lsfml-graphics -lsfml-window -lsfml-system -lsfml-audio && ./$OUTPUT
}
export -f sfml
export EDITOR=nvim
export VISUAL=nvim

function live() {
	EXTENSION=${1-cpp}
	COMMAND=${2-g++ main.$EXTENSION && ./a.out}
	watchexec -r -e $EXTENSION "$COMMAND"
}
export -f live

PS1='\[\e[0;95m\]\u@\h \W \$ \[\e[0;0m\]'
#PS1='\[\e[1;95m\]\u@\h \W \$ \[\e[0;0m\]'

#source /opt/esp-idf/export.sh
# old: PS1='[\u@\h \W]\$ '

#source /usr/share/nvm/init-nvm.sh
#
