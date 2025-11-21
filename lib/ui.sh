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
    local flag_file
    flag_file=$(mktemp)

    # Start the spinner in a subshell
    (
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
    local box_width=$((msg_len + 8))
    local indent=$(((cols - box_width) / 2))
    if [[ "$indent" -lt 0 ]]; then
        indent=0
    fi

    # Spinner characters
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    # Hide cursor and trap exit
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null; rm -f "$flag_file"' TERM INT EXIT

    local i=0
    while [[ -f "$flag_file" ]]; do
        # Move to the same line, clear it, and print the box
        printf "\r"
        tput el 2>/dev/null || printf "\e[K"
        printf "%${indent}s%s%s %s %s%s\n" "" "$box_top_left" "$box_horizontal" "$msg" "$box_horizontal" "$box_top_right"
        printf "%${indent}s%s  %s  %s\n" "" "$box_vertical" "${spin:$i:1}" "$box_vertical"
        printf "%${indent}s%s" "" "$box_bottom_left"
        for _ in $(seq 1 $((msg_len + 4))); do printf "%s" "$box_horizontal"; done
        printf "%s\n" "$box_bottom_right"
        tput cuu 3 2>/dev/null || printf "\e[3A" # Move cursor up 3 lines

        i=$(((i + 1) % ${#spin}))
        sleep 0.1
    done
    ) &

    # Return PID and flag file path to the caller
    echo "$! $flag_file"
}

# Hides the loading spinner
#
# Usage:
#   loader_info=$(show_loading "Doing something...")
#   loader_pid=$(echo "$loader_info" | cut -d' ' -f1)
#   flag_file=$(echo "$loader_info" | cut -d' ' -f2)
#   ... do a long running task ...
#   hide_loading "$loader_pid" "$flag_file"
hide_loading() {
    local pid="$1"
    local flag_file="$2"

    # Signal the spinner to stop by removing the flag file
    if [[ -n "$flag_file" ]]; then
        rm -f "$flag_file"
    fi

    # Wait for the spinner process to exit
    if [[ -n "$pid" ]]; then
        wait "$pid" 2>/dev/null || true
    fi
    # Clear the spinner lines and show cursor, only if in an interactive terminal
    if [[ -t 1 ]]; then
        printf "\r"
        tput el 2>/dev/null || printf "\e[K"
        tput cud1 2>/dev/null || printf "\e[B"
        tput el 2>/dev/null || printf "\e[K"
        tput cud1 2>/dev/null || printf "\e[B"
        tput el 2>/dev/null || printf "\e[K"
        tput cuu 2 2>/dev/null || printf "\e[2A"
        tput cnorm 2>/dev/null || printf "\e[?25h"
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
    selection=$(printf "No\nYes" | fzf --prompt "$prompt" --height 3 --border --header "Select an option" 2>/dev/null)
    local fzf_exit_code=$?

    if [[ $fzf_exit_code -eq 0 && "$selection" == "Yes" ]]; then
        return 0 # Yes
    elif [[ $fzf_exit_code -eq 130 ]]; then
        # User pressed Ctrl-C
        error "Prompt cancelled."
        return 1 # No
    else
        # All other cases (No, Esc, other errors)
        return 1 # No
    fi
}

# Shows a multi-line error message
#
# Usage:
#   show_multiline_error "Title" "Multi-line\nMessage"
show_multiline_error() {
    local title="$1"
    local message="$2"
    
    # Use colors if available (defined in colors.sh)
    local red=""
    local nc=""
    if [[ -n "$RED" ]]; then red="$RED"; fi
    if [[ -n "$NC" ]]; then nc="$NC"; fi
    
    echo -e "${red}${title}${nc}" >&2
    echo "$message" | sed 's/^/  /' >&2
}
