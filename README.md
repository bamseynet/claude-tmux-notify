# claude-tmux-notify

When a **Claude Code** session running inside **tmux** needs your attention — or
finishes and goes idle — this speaks the session's name out loud in a natural
voice, flashes the tmux status bar, and fires a desktop notification.

Run several Claude sessions across tmux windows and you'll hear exactly *which*
one needs you:

> 🔊 *"backend-api needs attention"*

Think "peon ping", but it tells you its name.

## How it works

Claude Code fires [hooks](https://docs.claude.com/en/docs/claude-code/hooks) on
lifecycle events. This wires two of them to a single script:

| Event | When it fires | You hear |
|-------|---------------|----------|
| `Notification` | Claude is waiting for input or permission | *"{window} needs attention"* |
| `Stop` | Claude finished a turn and is idle | *"{window} is done"* |

The session name is just the **tmux window name** (`#W`), so
`tmux rename-window backend-api` is all you need to label a session.

Each event is announced over three channels, any of which degrade gracefully if
a tool is missing:

1. **Voice** — [Piper](https://github.com/OHF-Voice/piper1-gpl) local neural TTS
   (falls back to `spd-say`/eSpeak if Piper or the voice model is unavailable)
2. **tmux status flash** — `tmux display-message`
3. **Desktop notification** — `notify-send`

Everything runs locally. Nothing leaves your machine.

## Requirements

- Linux with `tmux`, `aplay` (alsa-utils), `jq`, and `notify-send` (libnotify-bin)
- `python3` + `pip` (to install Piper)
- Claude Code, launched **inside** tmux

```bash
sudo apt install tmux alsa-utils jq libnotify-bin
```

## Install

```bash
git clone https://github.com/bamseynet/claude-tmux-notify.git
cd claude-tmux-notify
./install.sh
```

`install.sh` installs Piper, downloads the default voice
(`en_GB-alba-medium`, a warm Scottish female voice, ~60MB), and prints the hook
config to paste into `~/.claude/settings.json`. Merge that `hooks` block into
your existing settings (see [`settings.example.json`](settings.example.json)),
then **restart Claude Code** (or run `/hooks`) inside a tmux session.

## Usage

Name your tmux windows so you can tell sessions apart:

```bash
tmux rename-window backend-api
```

That's it. Leave the session working; when it needs you or finishes, you'll hear
its name.

## Choosing a voice

Piper ships many voices. Pick one during install:

```bash
VOICE=en_GB-northern_english_male-medium ./install.sh
```

...or override at runtime without reinstalling, via an env var Claude Code
inherits:

```bash
export PIPER_VOICE="$HOME/.local/share/piper-voices/en_GB-jenny_dioco-medium.onnx"
```

Some good UK English voices:

| Voice | Character |
|-------|-----------|
| `en_GB-alba-medium` | Female, Scottish *(default)* |
| `en_GB-jenny_dioco-medium` | Female, natural / conversational |
| `en_GB-semaine-medium` | Female, expressive |
| `en_GB-cori-high` | Female, high fidelity |
| `en_GB-northern_english_male-medium` | Male, Northern English |
| `en_GB-alan-medium` | Male, neutral |

Browse the full catalogue at
[rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices/tree/main/en).

## Configuration

`notify.sh` reads two environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `PIPER_BIN` | `~/.local/bin/piper` | Path to the Piper binary |
| `PIPER_VOICE` | `~/.local/share/piper-voices/en_GB-alba-medium.onnx` | Voice model to use |

## Testing without waiting for Claude

```bash
echo '{"message":"needs your permission to use Bash"}' | ./notify.sh attention
echo '{}' | ./notify.sh done
```

## Notes

- The `Stop` hook fires on **every** turn completion, so a busy session will
  announce "…is done" after each response. If that's too chatty, remove the
  `Stop` block and keep only `Notification`.
- No native Irish English voice exists in Piper — its English set is `en_GB`
  and `en_US` only. For an Irish accent you'd need a cloud TTS engine (e.g.
  Azure `en-IE-EmilyNeural`); this project stays fully local by design.

## License

MIT — see [LICENSE](LICENSE).
