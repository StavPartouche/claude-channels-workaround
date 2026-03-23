# telegram-bridge

Control Claude Code remotely from your phone via Telegram.

A bash bridge that polls the Telegram Bot API and pipes messages to `claude --print`, sending responses back. No Node.js, no Python — just `curl`, `jq`, and `tmux`.

## The Problem

Claude Code v2.1.80+ introduced a `--channels` flag for Telegram integration, but most users on API-based subscriptions get this error:

```
Channels are not currently available
```

This is a server-side feature flag that hasn't rolled out broadly yet. Open issues tracking this:

- [Issue #36503](https://github.com/anthropics/claude-code/issues/36503) — "Channels are not currently available"
- [Issue #37071](https://github.com/anthropics/claude-code/issues/37071) — Telegram channel not working for API users

## The Workaround

This plugin bypasses the channels system entirely with a bash bridge that polls the Telegram Bot API directly, pipes messages to `claude --print`, and sends responses back. No Node.js, no Python — just `curl`, `jq`, and `tmux`.

> **Credit:** The bridge script is based on the excellent workaround by [@tzachbon](https://github.com/tzachbon):
> [https://gist.github.com/tzachbon/60246bb96bac7f2e98637f08e895e939](https://gist.github.com/tzachbon/60246bb96bac7f2e98637f08e895e939)

## Install

```bash
claude plugin marketplace add https://github.com/StavPartouche/claude-channels-workaround
claude plugin install telegram-bridge@claude-channels-workaround
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
