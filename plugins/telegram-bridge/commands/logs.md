---
description: Show the last 50 lines of the Telegram Claude bridge log
allowed-tools: "*"
---

1. Run `tmux has-session -t claude-telegram 2>/dev/null && echo "RUNNING" || echo "NOT_RUNNING"` to get the session status.

2. Run `tail -n 50 ~/claude-telegram-bot/logs/bridge.log 2>/dev/null || echo "(no log file found — has the bridge been started yet?)"` and display the output.

3. If the session was `NOT_RUNNING`, suggest running `/telegram-bridge:start` to bring the bridge back up.
