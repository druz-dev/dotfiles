#!/bin/bash
#
# Waybar custom module for hyprsunset.
# Displays a 10-bar meter: white (6500K) → warm orange (2500K).
# Scroll adjusts temperature via hyprctl hyprsunset IPC.
#
MIN_K=2500
MAX_K=6500
STEP=200
BARS=10
DIM='#555ea5'

get_temp() {
    local t
    t=$(hyprctl hyprsunset temperature 2>/dev/null)
    if [[ -z "$t" || "$t" == *"Couldn't"* || "$t" == *"invalid"* ]]; then
        echo ""
        return 1
    fi
    echo "$t"
}

warmth_color() {
    local frac="$1"
    # White (255,255,255) to warm orange (255,106,0)
    local g=$(awk "BEGIN{printf \"%d\", 255 - (255-106)*$frac}")
    local b=$(awk "BEGIN{printf \"%d\", 255 - 255*$frac}")
    printf '#FF%02X%02X' "$g" "$b"
}

render_bars() {
    local temp="$1"

    local warmth_frac
    warmth_frac=$(awk "BEGIN{f=($MAX_K - $temp)/($MAX_K - $MIN_K); if(f<0)f=0; if(f>1)f=1; print f}")
    local active
    active=$(awk "BEGIN{printf \"%d\", $warmth_frac * $BARS + 0.5}")
    if (( active > BARS )); then active=$BARS; fi
    if (( active < 0 )); then active=0; fi

    local color
    color=$(warmth_color "$warmth_frac")

    local inactive=$(( BARS - active ))
    local out=""

    if (( active > 0 )); then
        out+="<span foreground='${color}'>"
        for ((i=0; i<active; i++)); do out+="|"; done
        out+="</span>"
    fi
    if (( inactive > 0 )); then
        out+="<span foreground='$DIM'>"
        for ((i=0; i<inactive; i++)); do out+="|"; done
        out+="</span>"
    fi

    echo "$out"
}

case "${1:-status}" in
    status)
        temp=$(get_temp) || exit 0
        bars=$(render_bars "$temp")
        echo "{\"text\": \"${bars}\", \"tooltip\": \"${temp}K\", \"class\": \"hyprsunset\"}"
        ;;
    warmer)
        hyprctl hyprsunset temperature -${STEP} >/dev/null 2>&1
        temp=$(get_temp) || exit 0
        if (( temp < MIN_K )); then
            hyprctl hyprsunset temperature $MIN_K >/dev/null 2>&1
        fi
        ;;
    cooler)
        hyprctl hyprsunset temperature +${STEP} >/dev/null 2>&1
        temp=$(get_temp) || exit 0
        if (( temp > MAX_K )); then
            hyprctl hyprsunset temperature $MAX_K >/dev/null 2>&1
        fi
        ;;
esac
