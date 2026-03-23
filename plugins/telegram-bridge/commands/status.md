---
description: Show whether the Telegram Claude bridge is running and print a quick-reference cheatsheet
allowed-tools: [Bash]
---

Check the bridge status and print a summary.

## Step 1 — Check tmux session

```bash
tmux has-session -t claude-telegram 2>/dev/null && echo "RUNNING" || echo "NOT_RUNNING"
```

## Step 2 — Print status summary

Based on the result, print:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Telegram Claude Bridge — Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Bot:        @AutodeskMAC_bot
  Session:    claude-telegram  [RUNNING or NOT RUNNING]

  Commands:
    /telegram-bot:start   — start the bridge
    /telegram-bot:logs    — view recent logs
    /telegram-bot:kill    — stop the bridge
    /telegram-bot:setup   — first-time setup guide
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Replace `[RUNNING or NOT RUNNING]` with the actual status from Step 1.
