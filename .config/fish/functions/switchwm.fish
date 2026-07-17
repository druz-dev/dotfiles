function switchwm --description "Toggle the tty1 WM between i3 and Hyprland, then exit the current one"
    # Detect what's running right now (env signatures first, sentinel as fallback)
    set -l current
    if test "$XDG_CURRENT_DESKTOP" = i3; or set -q I3SOCK
        set current i3
    else if test "$XDG_CURRENT_DESKTOP" = Hyprland; or set -q HYPRLAND_INSTANCE_SIGNATURE
        set current hyprland
    else if test -e ~/.use-i3
        set current i3
    else
        set current hyprland
    end

    if test "$current" = i3
        rm -f ~/.use-i3
        echo "switchwm: i3 -> Hyprland. Exiting i3; log back in on tty1 to land in Hyprland."
        sleep 1
        exec i3-msg exit
    else
        touch ~/.use-i3
        echo "switchwm: Hyprland -> i3. Exiting Hyprland; log back in on tty1 to land in i3."
        sleep 1
        exec hyprctl dispatch exit
    end
end
