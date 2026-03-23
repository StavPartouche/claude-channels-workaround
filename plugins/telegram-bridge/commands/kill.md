---
description: Stop the Telegram Claude bridge tmux session
allowed-tools: [Bash]
---

Stop the bridge.

## Step 1 — Check if running

```bash
tmux has-session -t claude-telegram 2>/dev/null && echo "RUNNING" || echo "NOT_RUNNING"
```

## Step 2 — Kill if running

If `NOT_RUNNING`: print "Bridge is not running — nothing to stop." and stop.

If `RUNNING`: run:

```bash
tmux kill-session -t claude-telegram
```

Then verify:

```bash
tmux has-session -t claude-telegram 2>/dev/null && echo "STILL_RUNNING" || echo "STOPPED"
```

## Step 3 — Report

If `STOPPED`: print "Bridge stopped. @AutodeskMAC_bot will no longer respond. Run /telegram-bridge:start to bring it back."

If `STILL_RUNNING`: print an error and the raw tmux output.
