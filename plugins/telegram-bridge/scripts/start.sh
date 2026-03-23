#!/bin/bash
BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_NAME="claude-telegram"
LOG_DIR="$BOT_DIR/logs"

mkdir -p "$LOG_DIR"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Session '$SESSION_NAME' already running."
  exit 0
fi

tmux new-session -d -s "$SESSION_NAME" -c "$BOT_DIR" \
  "$BOT_DIR/bridge.sh 2>&1 | tee -a $LOG_DIR/bridge.log"

echo "Started Telegram bridge in tmux session '$SESSION_NAME'"
