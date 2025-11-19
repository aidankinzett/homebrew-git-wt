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
    local msg="$1"
    local cols
    cols=$(tput cols)
    local half_cols=$((cols / 2))
    local half_msg_len=$(( (${#msg} + 4) / 2 ))
    local indent=$((half_cols - half_msg_len))

    # Spinner characters
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    # Hide cursor
    tput civis

    # Trap to ensure cursor is shown on exit
    trap 'tput cnorm; exit' INT TERM

    while true; do
        for i in $(seq 0 9); do
            # Move to the same line, clear it, and print the box
            printf "\r"
            tput el
            printf "%${indent}s╭─ %s ─╮\n" "" "$msg"
            printf "%${indent}s│  %s  │\n" "" "${spin:$i:1}"
            printf "%${indent}s╰────╯\n" ""
            tput cuu 2 # Move cursor up 2 lines
            sleep 0.1
        done
    done
}

# Hides the loading spinner
#
# Usage:
#   hide_loading $loader_pid
hide_loading() {
    local pid="$1"
    if kill -9 "$pid" 2>/dev/null; then
        # Clear the spinner lines and show cursor
        printf "\r"
        tput el
        tput el
        tput el
        tput cnorm
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
