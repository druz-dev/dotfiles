function tn -d "New named tmux session, or jump to it if it already exists"
    if test (count $argv) -lt 1
        echo "Usage: tn <session-name>"
        return 1
    end

    set name $argv[1]

    if not tmux has-session -t "=$name" 2>/dev/null
        tmux new-session -d -s "$name" -c (pwd)
    end

    # Every terminal starts in a disposable term-* session, so switch rather than
    # attach when already inside tmux — the term-* session is then reaped.
    if test -n "$TMUX"
        tmux switch-client -t "=$name"
    else
        tmux attach-session -t "=$name"
    end
end
