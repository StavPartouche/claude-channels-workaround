---
name: telegram-bridge:start
description: Start the Telegram Claude bridge in a background tmux session
user-invocable: true
allowed-tools:
  - Bash
---

1. Run `tmux has-session -t claude-telegram 2>/dev/null && echo "ALREADY_RUNNING" || echo "NOT_RUNNING"` to check the current state.

2. If the result is `ALREADY_RUNNING`, tell the user "Bridge is already running. Use /telegram-bridge:status to check it." and stop.

3. If the result is `NOT_RUNNING`, run `bash ~/claude-telegram-bot/start.sh` to start the bridge.

4. Wait 2 seconds by running `sleep 2`, then run `tmux has-session -t claude-telegram 2>/dev/null && echo "STARTED_OK" || echo "FAILED_TO_START"` to verify.

5. If `STARTED_OK`, tell the user "Bridge started. @AutodeskMAC_bot is now listening. Use /telegram-bridge:logs to see activity."

6. If `FAILED_TO_START`, show the error and suggest running `/telegram-bridge:setup` if the bot files are missing, or checking `~/claude-telegram-bot/logs/bridge.log`.
