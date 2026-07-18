#!/usr/bin/env bash
#
# Installer for claude-tmux-notify.
# Installs Piper (local neural TTS) + a default voice, then prints the hook
# config to add to your Claude Code settings.
#
# Usage:
#   ./install.sh                       # install Piper + default voice (en_GB-alba-medium)
#   VOICE=en_US-lessac-medium ./install.sh   # pick a different voice

set -euo pipefail

VOICE="${VOICE:-en_GB-alba-medium}"
VOICES_DIR="$HOME/.local/share/piper-voices"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

# --- Runtime deps ---------------------------------------------------------
missing=()
for bin in tmux aplay jq; do
  command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if ((${#missing[@]})); then
  say "Missing system tools: ${missing[*]}"
  echo "   Install them first, e.g.:  sudo apt install tmux alsa-utils jq libnotify-bin"
  exit 1
fi

# --- Piper ----------------------------------------------------------------
if ! command -v piper >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/piper" ]]; then
  say "Installing piper-tts (pip --user)"
  python3 -m pip install --user piper-tts
else
  say "Piper already installed"
fi

# --- Voice ----------------------------------------------------------------
# Map "en_GB-alba-medium" -> en/en_GB/alba/medium on the piper-voices repo.
lang="${VOICE%%-*}"                 # en_GB
rest="${VOICE#*-}"                  # alba-medium
speaker="${rest%-*}"               # alba
quality="${rest##*-}"             # medium
group="${lang%%_*}"               # en
base="https://huggingface.co/rhasspy/piper-voices/resolve/main/${group}/${lang}/${speaker}/${quality}"

mkdir -p "$VOICES_DIR"
if [[ -f "$VOICES_DIR/$VOICE.onnx" ]]; then
  say "Voice $VOICE already present"
else
  say "Downloading voice $VOICE (~60MB)"
  curl -fSL -o "$VOICES_DIR/$VOICE.onnx"      "$base/$VOICE.onnx"
  curl -fSL -o "$VOICES_DIR/$VOICE.onnx.json" "$base/$VOICE.onnx.json"
fi

chmod +x "$SCRIPT_DIR/notify.sh"

# --- Done -----------------------------------------------------------------
say "Installed. Add this to your Claude Code settings (~/.claude/settings.json):"
cat <<EOF

  "hooks": {
    "Notification": [
      { "hooks": [ { "type": "command", "command": "$SCRIPT_DIR/notify.sh attention" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "$SCRIPT_DIR/notify.sh done" } ] }
    ]
  }

EOF
if [[ "$VOICE" != "en_GB-alba-medium" ]]; then
  echo "Then set your voice:  export PIPER_VOICE=$VOICES_DIR/$VOICE.onnx"
fi
echo "Finally, restart Claude Code (or run /hooks to reload) inside tmux."
