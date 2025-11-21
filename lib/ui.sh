#!/bin/bash

# UI functions for git-wt

# Shows a loading spinner with a message in a box
#
# Usage:
#   show_loading "Doing something..." &
#   local loader_pid=$!
#   ... do a long running task ...
#   hide_loading $loader_pid
show_loading() {
    # Do nothing if not in an interactive terminal
    if [[ ! -t 1 ]]; then
        echo "$1"
        return
    fi

    local msg="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    # Consistent box-drawing characters
    local box_top_left="╭"
    local box_top_right="╮"
    local box_bottom_left="╰"
    local box_bottom_right="╯"
    local box_horizontal="─"
    local box_vertical="│"

    local msg_len=${#msg}
    local box_width=$((msg_len + 4))
    local indent=$(((cols - box_width) / 2))
    if [[ "$indent" -lt 0 ]]; then
        indent=0
    fi

    # Spinner characters
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    # Hide cursor
    tput civis 2>/dev/null

    while true; do
        for i in $(seq 0 9); do
            # Move to the same line, clear it, and print the box
            printf "\r"
            tput el 2>/dev/null
            printf "%${indent}s%s%s %s %s%s\n" "" "$box_top_left" "$box_horizontal" "$msg" "$box_horizontal" "$box_top_right"
            printf "%${indent}s%s  %s  %s\n" "" "$box_vertical" "${spin:$i:1}" "$box_vertical"
            printf "%${indent}s%s%s%s%s%s\n" "" "$box_bottom_left" "$box_horizontal" "$box_horizontal" "$box_horizontal" "$box_bottom_right"
            tput cuu 3 2>/dev/null # Move cursor up 3 lines
            sleep 0.15
        done
    done
}

# Hides the loading spinner
#
# Usage:
#   hide_loading $loader_pid
hide_loading() {
    local pid="$1"
    if [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null
        sleep 0.1 # Allow terminal buffer to flush
    fi
    # Clear the spinner lines and show cursor, only if in an interactive terminal
    if [[ -t 1 ]]; then
        printf "\r"
        tput el 2>/dev/null
        tput cud1 2>/dev/null
        tput el 2>/dev/null
        tput cud1 2>/dev/null
        tput el 2>/dev/null
        tput cuu 2 2>/dev/null # Move cursor back up to the original line
        tput cnorm 2>/dev/null
    fi
}

# Asks the user a yes/no question using fzf
#
# Usage:
#   if ask_yes_no "Do you want to proceed?"; then
#       echo "User said yes"
#   else
#       echo "User said no"
#   fi
#
# Note: Pressing Esc is treated as 'No'. 'No' is the default option for safety.
ask_yes_no() {
    local prompt="$1"
    local selection
    selection=$(printf "No\nYes" | fzf --prompt "$prompt" --height 3 --border --header "Select an option")
    if [[ "$selection" == "Yes" ]]; then
        return 0
    else
        return 1
    fi
}
