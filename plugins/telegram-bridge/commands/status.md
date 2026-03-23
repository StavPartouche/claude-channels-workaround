---
description: Show whether the Telegram Claude bridge is running and print a quick-reference cheatsheet
allowed-tools: [Bash]
---

1. Run `tmux has-session -t claude-telegram 2>/dev/null && echo "RUNNING" || echo "NOT_RUNNING"` to check if the bridge is active.

2. Print the following status block, substituting the actual result for [STATUS]:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Telegram Claude Bridge — Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Bot:        @AutodeskMAC_bot
  Session:    claude-telegram  [STATUS]

  Commands:
    /telegram-bridge:start   — start the bridge
    /telegram-bridge:logs    — view recent logs
    /telegram-bridge:kill    — stop the bridge
    /telegram-bridge:setup   — first-time setup guide
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
