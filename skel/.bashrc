# ~/.bashrc — persisted on the Railway volume. Edit freely.
[ -z "$PS1" ] && return
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=vim
alias ll='ls -alF'
PS1='\[\e[1;32m\]\u@claude-box\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
# `cl` = Claude Code inside a tmux session that survives disconnects.
cl() { tmux new -A -s claude "claude $*"; }
[ -f ~/.motd ] && cat ~/.motd
