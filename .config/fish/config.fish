if status is-interactive
    # Every terminal gets its own disposable tmux session (reaped on close,
    # see destroy-unattached in ~/.tmux.conf). prefix+d to keep one alive.
    if not set -q TMUX; and not set -q NVIM; and command -q tmux; and test "$TERM" != dumb
        exec tmux new-session -s term-$fish_pid
    end

    # Commands to run in interactive sessions can go here
    alias ls=exa
    alias gsu="git submodule update --recursive --init"
    alias mux=tmuxinator
    alias ta="tmux a"
    # tn is a function now (functions/tn.fish) — works from inside tmux too
    alias lg="lazygit"
    alias oc="opencode"
    alias vim="nvim"
    alias slack="/snap/bin/slack"

    set -x EDITOR nvim
    set -x VISUAL nvim

    set -e ANTHROPIC_BASE_URL
    set -e ANTHROPIC_AUTH_TOKEN
    set -e ANTHROPIC_MODEL
    # GITLAB_TOKEN is set in the gitignored conf.d/secrets.fish
    set -x GITLAB_HOST "https://gitlab.appear.net"

    eval (ssh-agent -c)
    set -x SSH_AUTH_SOCK /run/user/1001/keyring/ssh
    clear
    set fish_greeting
end

function wt
    if not git rev-parse --show-toplevel &>/dev/null
        echo "Not in a git repository"
        return 1
    end

    set repo (basename (git worktree list | head -1 | awk '{print $1}'))

    switch $argv[1]
        case new
            if git show-ref --verify --quiet refs/heads/$argv[2]
                git worktree add ../$repo@$argv[2] $argv[2] && cd ../$repo@$argv[2]
            else if git fetch origin $argv[2] &>/dev/null && git show-ref --verify --quiet refs/remotes/origin/$argv[2]
                git worktree add ../$repo@$argv[2] -b $argv[2] origin/$argv[2] && cd ../$repo@$argv[2]
            else
                for b in master main
                    if git show-ref --verify --quiet refs/heads/$b
                        git worktree add ../$repo@$argv[2] -b $argv[2] $b && cd ../$repo@$argv[2]
                        return
                    end
                end
                echo "No master or main branch found"
                return 1
            end

        case go
            if test (count $argv) -lt 2
                if not command -q fzf
                    echo "fzf is not installed"
                    return 1
                end
                set match (git worktree list | fzf | awk '{print $1}')
                if test -z "$match"
                    return 1
                end
                cd $match
            else
                set matches (git worktree list | grep "$argv[2]")
                if test (count $matches) -eq 0
                    echo "No worktree matching '$argv[2]'"
                    return 1
                else if test (count $matches) -eq 1
                    cd (echo $matches[1] | awk '{print $1}')
                else
                    echo "Multiple matches:"
                    for m in $matches
                        echo "  $m"
                    end
                    return 1
                end
            end

        case rm
            if not git worktree list | grep -q "$repo@$argv[2]"
                echo "No worktree '$repo@$argv[2]' found"
                return 1
            end
            cd (git worktree list | head -1 | awk '{print $1}')
            if contains -- --force $argv
                git worktree remove --force ../$repo@$argv[2] && git branch -D $argv[2]
            else
                git worktree remove ../$repo@$argv[2] && git branch -d $argv[2]
            end

        case ls
            git worktree list

        case '*'
            echo "Usage: wt [new|go|rm|ls] <name>"
            echo "  wt new <branch>        Worktree for branch (creates from master/main if new)"
            echo "  wt go                  Fuzzy pick a worktree with fzf"
            echo "  wt go <name>           Jump to a worktree by name"
            echo "  wt rm <branch>         Remove worktree and branch"
            echo "  wt rm <branch> --force Force remove (discards changes)"
            echo "  wt ls                  List all worktrees"
    end
end

# function vim
#     if test "$TERM" = xterm-kitty
#         kitty @ set-spacing padding=0 margin=0
#         command nvim $argv
#         kitty @ set-spacing padding=4 margin=0
#     else
#         command nvim $argv
#     end
# end

zoxide init fish | source

# opencode
fish_add_path /home/ota/.opencode/bin

# Auto-launch WM on TTY1 (sentinel ~/.use-i3 selects i3; remove it to go back to Hyprland)
if status is-login; and test -z "$DISPLAY" -a -z "$WAYLAND_DISPLAY" -a "$XDG_VTNR" = 1
    if test -e ~/.use-i3
        set -x XDG_CURRENT_DESKTOP i3
        exec startx
    else
        set -x XDG_CURRENT_DESKTOP Hyprland
        exec start-hyprland
    end
end
