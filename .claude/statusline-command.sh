#!/bin/bash

# Function to abbreviate numbers (e.g., 2621 -> 2.6k, 200000 -> 200k)
abbreviate_number() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        # Millions
        echo "$(echo "scale=1; $num / 1000000" | bc | sed 's/\.0$//')m"
    elif [ "$num" -ge 1000 ]; then
        # Thousands
        echo "$(echo "scale=1; $num / 1000" | bc | sed 's/\.0$//')k"
    else
        echo "$num"
    fi
}

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
model=$(echo "$input" | jq -r '.model.display_name // empty')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

# Abbreviate home directory in path
current_dir="${current_dir/#$HOME/~}"

# Get git branch if in a repo (skip optional locks)
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" --no-optional-locks branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        git_info=" on $(printf '\033[35m')$branch$(printf '\033[0m')"
    else
        git_info=""
    fi
else
    git_info=""
fi

# Format output style if available
if [ -n "$output_style" ]; then
    style_info=" $(printf '\033[36m')[$output_style]$(printf '\033[0m')"
else
    style_info=""
fi

# Create progress bar and token info if available
if [ -n "$used" ] && [ "$used" != "null" ]; then
    # Calculate total tokens used
    total_used=$((total_input + total_output))

    # Create progress bar (20 characters wide)
    bar_width=20
    filled=$(echo "scale=0; ($used * $bar_width) / 100" | bc)
    empty=$((bar_width - filled))

    # Choose color based on used percentage (inverse of remaining)
    if [ "$used" -lt 50 ]; then
        bar_color='\033[32m'  # Green
    elif [ "$used" -lt 80 ]; then
        bar_color='\033[33m'  # Yellow
    else
        bar_color='\033[31m'  # Red
    fi

    # Build progress bar
    progress_bar="["
    for ((i=0; i<filled; i++)); do
        progress_bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        progress_bar+="░"
    done
    progress_bar+="]"

    # Format token display with abbreviated numbers
    total_used_abbrev=$(abbreviate_number $total_used)
    context_size_abbrev=$(abbreviate_number $context_size)
    context_info=" $(printf "$bar_color")$progress_bar$(printf '\033[0m') $(printf '\033[33m')$used%$(printf '\033[0m') $(printf '\033[90m')($total_used_abbrev/$context_size_abbrev)$(printf '\033[0m')"
else
    context_info=""
fi

# Build and print the status line
printf '\033[34m%s\033[0m in \033[32m%s\033[0m%s%s%s' \
    "$model" \
    "$current_dir" \
    "$git_info" \
    "$style_info" \
    "$context_info"
