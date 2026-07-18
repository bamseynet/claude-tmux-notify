#!/usr/bin/env bash
#
# Claude Code tmux notifier.
# Announces the current session's tmux window name when it needs attention
# or finishes, via three channels: TTS, a tmux status flash, and a desktop
# notification.
#
# Usage (from a Claude Code hook):
#   notify.sh attention   # Notification event: waiting for input / permission
#   notify.sh done         # Stop event: session finished, now idle
#
# The hook JSON payload is read from stdin.

set -euo pipefail

# --- TTS config -----------------------------------------------------------
# Piper (local neural voice). Falls back to spd-say/espeak if unavailable.
PIPER_BIN="${PIPER_BIN:-$HOME/.local/bin/piper}"
PIPER_VOICE="${PIPER_VOICE:-$HOME/.local/share/piper-voices/en_GB-alba-medium.onnx}"

# Speak $1 aloud. Piper synthesizes to a temp WAV (piping the WAV header is
# unreliable) and aplay plays it; fall back to spd-say if piper/voice missing.
speak() {
  local text="$1"
  if [[ -x "$PIPER_BIN" && -f "$PIPER_VOICE" ]] && command -v aplay >/dev/null 2>&1; then
    local wav
    wav="$(mktemp --suffix=.wav)"
    if printf '%s' "$text" | "$PIPER_BIN" -m "$PIPER_VOICE" -f "$wav" >/dev/null 2>&1; then
      aplay -q "$wav" >/dev/null 2>&1
    fi
    rm -f "$wav"
  else
    spd-say -- "$text" >/dev/null 2>&1
  fi
}

# Internal detached-TTS entrypoint (see Channel 1). Speaks its argument and
# exits without reading stdin, so it can run in its own session, independent of
# the hook that spawned it.
if [[ "${1:-}" == "__speak" ]]; then
  speak "${2:-}"
  exit 0
fi

mode="${1:-attention}"
payload="$(cat)"

# --- Resolve the session name from the tmux window ------------------------
# $TMUX_PANE is set because Claude was launched inside tmux. Fall back to a
# generic name if we're somehow not in tmux.
name="$(tmux display-message -p -t "${TMUX_PANE:-}" '#W' 2>/dev/null || true)"
name="${name:-claude}"

# --- Build the phrase per mode --------------------------------------------
case "$mode" in
  done)
    spoken="${name} is done"
    # Stop payloads have no human message; keep it simple.
    detail="finished — ready for you"
    icon="✅"
    urgency="low"
    ;;
  attention | *)
    # Notification payloads carry a human-readable reason, e.g.
    # "Claude needs your permission to use Bash".
    detail="$(printf '%s' "$payload" | jq -r '.message // "needs attention"')"
    # Speak the reason, not just a generic phrase. Claude's messages start with
    # "Claude " — swap that for the session name so it reads naturally, e.g.
    # "backend-api needs your permission to use Bash".
    spoken="${name} ${detail#Claude }"
    icon="🔔"
    urgency="normal"
    ;;
esac

# --- Channel 1: TTS --------------------------------------------------------
# Detach so playback survives this hook returning (Claude Code tears down the
# hook's process group on exit, which would otherwise kill a plain background
# job mid-sentence). setsid gives it a fresh session; fall back to a background
# job if setsid is unavailable.
if command -v setsid >/dev/null 2>&1; then
  setsid -f "$0" __speak "$spoken" </dev/null >/dev/null 2>&1
else
  speak "$spoken" &
fi

# --- Channel 2: tmux status flash -----------------------------------------
tmux display-message -t "${TMUX_PANE:-}" "${icon} ${name}: ${detail}" >/dev/null 2>&1 || true

# --- Channel 3: desktop notification --------------------------------------
notify-send -u "$urgency" "${icon} Claude: ${name}" "$detail" >/dev/null 2>&1 || true

exit 0
