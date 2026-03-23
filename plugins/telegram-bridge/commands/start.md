---
description: Start the Telegram Claude bridge in a background tmux session
allowed-tools: [Bash]
---

Start the Telegram bridge.

## Step 1 — Check if already running

```bash
tmux has-session -t claude-telegram 2>/dev/null && echo "ALREADY_RUNNING" || echo "NOT_RUNNING"
```

## Step 2 — Start if not running

If `ALREADY_RUNNING`: print "Bridge is already running. Use /telegram-bot:status to check it." and stop.

If `NOT_RUNNING`: run:

```bash
bash ~/claude-telegram-bot/start.sh
```

Then verify it started:

```bash
sleep 2 && tmux has-session -t claude-telegram 2>/dev/null && echo "STARTED_OK" || echo "FAILED_TO_START"
```

## Step 3 — Report result

If `STARTED_OK`: print "Bridge started. @AutodeskMAC_bot is now listening. Use /telegram-bot:logs to see activity."

If `FAILED_TO_START`: print the error and suggest running `/telegram-bot:setup` if the bot files are missing, or checking `~/claude-telegram-bot/logs/bridge.log`.
