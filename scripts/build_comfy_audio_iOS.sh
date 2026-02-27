#!/bin/bash
set -euo pipefail

# Colors
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}→${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}✓${RESET} $*"; }
step()    { echo -e "${MAGENTA}${BOLD}◆${RESET} ${BOLD}$*${RESET}"; }
warn()    { echo -e "${YELLOW}${BOLD}⚠${RESET} $*"; }
die()     { echo -e "${RED}${BOLD}✗${RESET} $*" >&2; exit 1; }

line=$(xcrun xctrace list devices \
  | sed -n 's/^[[:space:]]*//p' \
  | grep -v '^==' \
  | grep -v '^$' \
  | fzf --query="${1:-}" --prompt="Pick a device: ")
[ -z "$line" ] && exit 0

PROJECTPATH="ComfyAudio/ComfyAudio.xcodeproj"
SCHEME="ComfyAudio"
DERIVED=".derivedData"

udid=$(echo "$line" | sed -nE 's/.*\(([0-9A-Fa-f-]+)\)$/\1/p')
name=$(echo "$line" | sed -E 's/[[:space:]]*\([0-9A-Fa-f-]+\)$//')

info "Selected Device: ${BOLD}${BLUE}$name${RESET}"
info "UDID: ${DIM}$udid${RESET}"

step "Building $SCHEME..."
xcodebuild \
  -project "$PROJECTPATH" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=$udid" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  build

APP_PATH=$(find "$DERIVED/Build/Products/Debug-iphoneos" -maxdepth 1 -name "*.app" | head -n 1)
[ -z "$APP_PATH" ] && die "No .app found in build output"
success "Built: ${DIM}$APP_PATH${RESET}"

step "Installing on device..."
xcrun devicectl device install app \
  --device "$udid" \
  "$APP_PATH"
success "Installed"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")
info "Bundle ID: ${DIM}$BUNDLE_ID${RESET}"

step "Launching..."
xcrun devicectl device process launch \
  --device "$udid" \
  "$BUNDLE_ID"
success "Launched ${BOLD}${GREEN}$BUNDLE_ID${RESET} on ${BLUE}$name${RESET} 🚀"
