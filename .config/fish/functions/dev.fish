function dev -d "Open a tmux session with cli, nvim, and claude in the given directory"
    if test (count $argv) -lt 1
        set dir (pwd)
    else
        set dir (realpath $argv[1])
    end

    if not test -d "$dir"
        echo "Directory '$dir' does not exist"
        return 1
    end

    set name (basename $dir)

    if test -n "$TMUX"
        echo "Already in a tmux session. Detach first or run from outside tmux."
        return 1
    end

    if tmux has-session -t "$name" 2>/dev/null
        tmux attach-session -t "$name"
        return
    end

    tmux new-session -d -s "$name" -c "$dir" -n cli
    tmux new-window -t "$name" -c "$dir" -n nvim
    tmux send-keys -t "$name:nvim" nvim Enter
    tmux new-window -t "$name" -c "$dir" -n claude
    tmux send-keys -t "$name:claude" claude Enter
    tmux select-window -t "$name:cli"
    tmux attach-session -t "$name"
end
