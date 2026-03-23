---
description: Show the last 50 lines of the Telegram Claude bridge log
allowed-tools: [Bash]
---

Show recent bridge activity.

## Step 1 — Check if bridge is running

```bash
tmux has-session -t claude-telegram 2>/dev/null && echo "RUNNING" || echo "NOT_RUNNING"
```

## Step 2 — Print the last 50 log lines

```bash
tail -n 50 ~/claude-telegram-bot/logs/bridge.log 2>/dev/null || echo "(no log file found — has the bridge been started yet?)"
```

Print the output under a clear header showing the session status from Step 1.

## Step 3 — Tip

If the bridge is `NOT_RUNNING`, suggest running `/telegram-bridge:start` to bring it back up.
