---
description: Stop the Telegram Claude bridge tmux session
allowed-tools: "*"
---

1. Run `tmux has-session -t claude-telegram 2>/dev/null && echo "RUNNING" || echo "NOT_RUNNING"` to check the current state.

2. If `NOT_RUNNING`, tell the user "Bridge is not running — nothing to stop." and stop.

3. If `RUNNING`, run `tmux kill-session -t claude-telegram` to stop the bridge.

4. Run `tmux has-session -t claude-telegram 2>/dev/null && echo "STILL_RUNNING" || echo "STOPPED"` to verify.

5. If `STOPPED`, tell the user "Bridge stopped. @AutodeskMAC_bot will no longer respond. Run /telegram-bridge:start to bring it back."

6. If `STILL_RUNNING`, show an error with the raw output.
