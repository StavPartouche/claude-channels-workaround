# telegram-bridge

Control Claude Code remotely from your phone via Telegram.

A bash bridge that polls the Telegram Bot API and pipes messages to `claude --print`, sending responses back. No Node.js, no Python — just `curl`, `jq`, and `tmux`.

## Why

Claude Code v2.1.80+ has a `--channels` flag for Telegram integration, but it returns _"Channels are not currently available"_ for most users on API-based subscriptions. This bridge bypasses the channels system entirely.

> **Credit:** The bridge script is based on the excellent workaround by [@tzachbon](https://github.com/tzachbon):
> [https://gist.github.com/tzachbon/60246bb96bac7f2e98637f08e895e939](https://gist.github.com/tzachbon/60246bb96bac7f2e98637f08e895e939)
>
> Tracking issues: [#36503](https://github.com/anthropics/claude-code/issues/36503) · [#37071](https://github.com/anthropics/claude-code/issues/37071)

## Install

```bash
claude plugin add-marketplace claude-telegram-bridge --github StavPartouche/claude-telegram-bridge
claude plugin install telegram-bridge@claude-telegram-bridge
```

## Commands

| Command | Description |
|---------|-------------|
| `/telegram-bridge:setup` | Guided first-time setup — walks you through bot creation, config, and starting the bridge |
| `/telegram-bridge:start` | Start the bridge in a background tmux session |
| `/telegram-bridge:status` | Check if the bridge is running |
| `/telegram-bridge:logs` | View the last 50 lines of the bridge log |
| `/telegram-bridge:kill` | Stop the bridge |

**First time?** Just run `/telegram-bridge:setup` — it handles everything step by step.

## How it works

1. `bridge.sh` long-polls Telegram's `getUpdates` API (30s timeout)
2. Incoming messages are checked against an allowlist in `~/.claude/channels/telegram/access.json`
3. A typing indicator fires every 4 seconds while Claude processes
4. The message is piped to `claude --print --system-prompt-file CLAUDE.md`
5. The response is sent back via Telegram's `sendMessage` API, chunked at 4096 chars

## Prerequisites

- Claude Code installed and authenticated (`claude --print "hello"` should work)
- `curl` and `jq` (install via `brew install jq` on macOS)
- `tmux` (install via `brew install tmux`)
- A Telegram account

## License

MIT
