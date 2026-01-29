#!/usr/bin/env zsh
# 09-dock.sh — Configure macOS Dock layout via dockutil

step "Dock Layout"

# ── Guard: dockutil must be installed ────────────────────────────────────────
if ! command -v dockutil &>/dev/null; then
  skip "dockutil not installed — skipping Dock layout"
  return 0 2>/dev/null || exit 0
fi

# ── App list (exact order) ───────────────────────────────────────────────────
dock_apps=(
  "/System/Applications/Apps.app"
  "/Applications/Zen.app"
  "/Applications/Warp.app"
  "/Applications/Cursor.app"
  "/System/Applications/Messages.app"
  "/System/Applications/Reminders.app"
  "/System/Applications/Notes.app"
  "/System/Applications/System Settings.app"
)

# ── Validate paths ──────────────────────────────────────────────────────────
missing=0
for app in "${dock_apps[@]}"; do
  if [[ ! -d "$app" ]]; then
    warn "App not found: $app"
    (( missing++ ))
  fi
done

log "Clearing all Dock items..."
dockutil --remove all --no-restart

# ── Add apps (left side) ────────────────────────────────────────────────────
for app in "${dock_apps[@]}"; do
  if [[ -d "$app" ]]; then
    dockutil --add "$app" --no-restart
  fi
done

# ── Add Downloads folder (right side) ───────────────────────────────────────
log "Adding Downloads folder..."
dockutil --add "${HOME}/Downloads" --view fan --sort dateadded

ok "Dock layout configured (${#dock_apps[@]} apps, 1 folder, $missing missing)"
