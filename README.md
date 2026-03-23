# claude-channels-workaround

A community marketplace of Claude Code plugins that work around the missing `--channels` feature.

## The Problem

Claude Code v2.1.80+ introduced a `--channels` flag that enables remote control via messaging platforms like Telegram. But most users on API-based subscriptions hit this wall:

```
Channels are not currently available
```

This is a server-side feature flag that Anthropic has not rolled out broadly. The community is tracking it here:

- [Issue #36503](https://github.com/anthropics/claude-code/issues/36503) — "Channels are not currently available"
- [Issue #37071](https://github.com/anthropics/claude-code/issues/37071) — Telegram channel not working for API users

Until the official flag ships for everyone, this marketplace provides platform-specific workarounds that bypass the channels system entirely.

## Available Plugins

| Plugin | Platform | Description |
|--------|----------|-------------|
| [telegram-bridge](./plugins/telegram-bridge/README.md) | Telegram | Polls the Telegram Bot API and pipes messages to `claude --print` |

## Install

```bash
claude plugin marketplace add https://github.com/StavPartouche/claude-channels-workaround
claude plugin install telegram-bridge@claude-channels-workaround
```

Then run `/telegram-bridge:setup` in Claude Code — it walks you through everything.

## Contributing

Want to add a workaround for another platform (Discord, Slack, WhatsApp...)? PRs are very welcome.

### How to add a new platform plugin

1. Fork this repo
2. Create a new directory under `plugins/` — e.g. `plugins/discord-bridge/`
3. Follow this structure:

```
plugins/your-platform-bridge/
├── .claude-plugin/
│   └── plugin.json        # name, version, description, author
├── commands/
│   ├── setup.md           # guided first-time setup
│   ├── start.md           # start the bridge
│   ├── status.md          # check if running
│   ├── logs.md            # view logs
│   └── kill.md            # stop the bridge
├── scripts/
│   ├── bridge.sh          # the polling/bridge script
│   └── start.sh           # session manager (tmux or similar)
└── README.md              # explain the platform, credit sources, link issues
```

4. Register your plugin in `.claude-plugin/marketplace.json` by adding an entry to the `plugins` array:

```json
{
  "name": "your-platform-bridge",
  "source": "./plugins/your-platform-bridge",
  "description": "One-line description"
}
```

5. Open a PR with a clear description of the platform and how your bridge works.

### Guidelines

- **Credit your sources** — if your bridge is based on someone else's gist, script, or idea, link to them prominently in your README
- **Security first** — bot tokens and credentials must be stored in `.env` files with `chmod 600`, never logged or committed
- **Setup command is mandatory** — every plugin must have a `setup.md` that guides a first-time user through the full process
- **No external dependencies beyond `curl` and `jq`** — keep it simple; no Node.js, Python, or package managers required unless absolutely necessary

## License

MIT
