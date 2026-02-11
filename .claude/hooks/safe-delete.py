#!/usr/bin/env python3
"""
Claude Code PreToolUse hook for non-destructive file operations.
Redirects rm/rmdir to trash, blocks shred and find -delete.
"""
import json
import os
import re
import shutil
import sys
from datetime import datetime

# Optional: Enable logging to track redirected operations
LOG_ENABLED = True
LOG_FILE = os.path.expanduser("~/.claude/trash-redirect.log")

def log(message: str):
    if LOG_ENABLED:
        try:
            os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
            with open(LOG_FILE, "a") as f:
                f.write(f"[{datetime.now().isoformat()}] {message}\n")
        except Exception:
            pass  # Don't fail on logging errors

def deny(reason: str):
    log(f"DENIED: {reason}")
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason
        }
    }))
    sys.exit(0)

def allow_with_updated_command(new_command: str, reason: str):
    log(f"REWRITTEN: {reason} -> {new_command}")
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": reason,
            "updatedInput": {
                "command": new_command
            }
        }
    }))
    sys.exit(0)

def allow():
    sys.exit(0)

def check_trash_available():
    """Check if trash command is available."""
    return shutil.which("trash") is not None

# Read hook input
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)  # Invalid input, allow default behavior

# Only intercept Bash tool calls
if data.get("tool_name") != "Bash":
    allow()

tool_input = data.get("tool_input") or {}
cmd = (tool_input.get("command") or "").strip()

if not cmd:
    allow()

# Check for trash availability once
TRASH_AVAILABLE = check_trash_available()

# =============================================================================
# PATTERN DEFINITIONS
# =============================================================================

# Commands that should be redirected to trash
REDIRECT_PATTERNS = [
    r"^(?:/bin/)?rm(?:\s|$)",        # rm, /bin/rm
    r"^(?:/bin/)?rmdir(?:\s|$)",     # rmdir (empty directories)
]

# Dangerous patterns that should be blocked entirely (minimal scope)
BLOCK_PATTERNS = [
    (r"shred\s", "Blocked: 'shred' performs secure delete and cannot be recovered"),
    (r"find\s+.*\s+-delete", "Blocked: 'find -delete' - use 'find ... -exec trash {} +' instead"),
]

# Patterns indicating compound/complex commands (be more careful)
COMPOUND_INDICATORS = [
    r"[;&|]",           # Command separators
    r"\$\(",            # Command substitution
    r"`",               # Backtick substitution
    r"\|\|",            # Or operator
    r"&&",              # And operator
]

# =============================================================================
# SAFETY CHECKS
# =============================================================================

# Block sudo with destructive commands
if re.match(r"^sudo\s+(rm|rmdir|shred)", cmd):
    deny("Blocked: sudo with destructive command. Remove sudo to allow trash redirection.")

# Check for blocked patterns
for pattern, reason in BLOCK_PATTERNS:
    if re.search(pattern, cmd, re.IGNORECASE):
        deny(reason)

# Check for compound commands containing rm-like operations
is_compound = any(re.search(p, cmd) for p in COMPOUND_INDICATORS)

if is_compound:
    # Check if any destructive command is present in compound
    destructive_in_compound = (
        re.search(r"(^|\s|;|&|\|)(/bin/)?(rm|rmdir)(\s|$|;|&|\|)", cmd) or
        re.search(r"\$\(.*\brm\b", cmd) or
        re.search(r"`.*\brm\b", cmd)
    )
    if destructive_in_compound:
        deny("Blocked: compound command containing destructive operation. "
             "Split into separate commands so rm can be safely redirected to trash.")
    allow()

# =============================================================================
# REDIRECT TO TRASH
# =============================================================================

for pattern in REDIRECT_PATTERNS:
    match = re.match(pattern, cmd)
    if match:
        if not TRASH_AVAILABLE:
            deny("Cannot redirect to trash: 'trash' command not found. "
                 "Install with: brew install macos-trash")

        # Extract the command name and replace with trash
        cmd_end = match.end() - 1 if cmd[match.end()-1:match.end()] == ' ' else match.end()
        original_cmd = cmd[:cmd_end].split('/')[-1]  # Get just 'rm' or 'rmdir'

        # For rmdir, trash handles it the same way
        new_cmd = "trash" + cmd[cmd_end:]

        allow_with_updated_command(
            new_cmd,
            f"Redirected '{original_cmd}' to trash (recoverable via Finder)"
        )

# =============================================================================
# OPTIONAL: MV OVERWRITE PROTECTION
# =============================================================================

# Detect mv that would overwrite an existing file
# This is tricky because we'd need filesystem access to check if target exists
# For now, just log mv commands for awareness
if re.match(r"^mv\s", cmd):
    log(f"INFO: mv command executed (may overwrite): {cmd}")

# Allow all other commands
allow()
