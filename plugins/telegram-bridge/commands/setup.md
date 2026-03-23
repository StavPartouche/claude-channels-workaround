---
description: Guided first-time setup of the Telegram Claude bridge (workaround for API-based Claude subscriptions)
allowed-tools: [Bash, Write]
---

Guide the user through setup one step at a time. Wait for confirmation before moving to the next step. If something fails, troubleshoot before continuing.

1. Check prerequisites by running each of these and reporting the results:
   - `claude --version 2>/dev/null || echo "MISSING: claude not found"`
   - `curl --version 2>/dev/null | head -1 || echo "MISSING: curl not found"`
   - `jq --version 2>/dev/null || echo "MISSING: jq not found"`
   - `tmux -V 2>/dev/null || echo "MISSING: tmux not found"`
   If `jq` or `tmux` are missing on macOS, offer to run `brew install jq tmux` to fix it. Wait for all prerequisites to be confirmed before continuing.

2. Ask the user to create a Telegram bot: open Telegram, message @BotFather, send `/newbot`, choose a display name and a username ending in `bot`. BotFather will give a token like `123456789:AAH...`. Ask them to paste it here.

3. Once the user pastes their token, store it and run `curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.from | {id, username, first_name}'` to get their Telegram user ID. If the result shows nulls, tell them to open Telegram, find their bot, send it `/start`, and confirm when done. Then re-run the curl command and extract the numeric `id`.

4. Create the config files by running:
   - `mkdir -p ~/.claude/channels/telegram`
   - `echo "TELEGRAM_BOT_TOKEN=<TOKEN>" > ~/.claude/channels/telegram/.env`
   - `chmod 600 ~/.claude/channels/telegram/.env`
   Then write `~/.claude/channels/telegram/access.json` with the content: `{"dmPolicy":"allowlist","allowFrom":["<USER_ID>"],"groups":{},"pending":{}}` substituting the real user ID.

5. Create the bot directory by running `mkdir -p ~/claude-telegram-bot/logs`. Then write `~/claude-telegram-bot/CLAUDE.md` with: "You are a helpful assistant responding via Telegram. Reply directly and concisely. Output only your answer, nothing else."

6. Write `~/claude-telegram-bot/bridge.sh` with the following content, then run `chmod +x ~/claude-telegram-bot/bridge.sh`:

```
#!/bin/bash
BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$HOME/.claude/channels/telegram/.env"
ACCESS_FILE="$HOME/.claude/channels/telegram/access.json"
SYSTEM_PROMPT_FILE="$BOT_DIR/CLAUDE.md"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi
TOKEN="${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
API="https://api.telegram.org/bot${TOKEN}"
ALLOWED_IDS=()
if [[ -f "$ACCESS_FILE" ]]; then
  while IFS= read -r id; do ALLOWED_IDS+=("$id"); done < <(python3 -c "import json; [print(x) for x in json.load(open('$ACCESS_FILE')).get('allowFrom', [])]" 2>/dev/null)
fi
is_allowed() { local sid="$1"; for id in "${ALLOWED_IDS[@]}"; do [[ "$id" == "$sid" ]] && return 0; done; return 1; }
send_message() {
  local chat_id="$1" text="$2" reply_to="${3:-}"
  while [[ ${#text} -gt 4096 ]]; do
    local chunk="${text:0:4096}"; text="${text:4096}"
    local p=$(jq -n --arg c "$chat_id" --arg t "$chunk" '{chat_id:$c,text:$t}')
    [[ -n "$reply_to" ]] && p=$(echo "$p" | jq --arg r "$reply_to" '. + {reply_parameters:{message_id:($r|tonumber)}}') && reply_to=""
    curl -s -X POST "$API/sendMessage" -H "Content-Type: application/json" -d "$p" > /dev/null
  done
  if [[ -n "$text" ]]; then
    local p=$(jq -n --arg c "$chat_id" --arg t "$text" '{chat_id:$c,text:$t}')
    [[ -n "$reply_to" ]] && p=$(echo "$p" | jq --arg r "$reply_to" '. + {reply_parameters:{message_id:($r|tonumber)}}')
    curl -s -X POST "$API/sendMessage" -H "Content-Type: application/json" -d "$p" > /dev/null
  fi
}
start_typing() { local cid="$1"; while true; do curl -s -X POST "$API/sendChatAction" -H "Content-Type: application/json" -d "{\"chat_id\":\"$cid\",\"action\":\"typing\"}" > /dev/null 2>&1; sleep 4; done; }
OFFSET=0
echo "telegram-bridge: starting as $(curl -s "$API/getMe" | jq -r '.result.username')"
echo "telegram-bridge: allowed IDs: ${ALLOWED_IDS[*]}"
while true; do
  UPDATES=$(curl -s --max-time 35 "$API/getUpdates?offset=${OFFSET}&timeout=30" 2>/dev/null || true)
  [[ -z "$UPDATES" ]] || [[ "$(echo "$UPDATES" | jq -r '.ok' 2>/dev/null)" != "true" ]] && sleep 2 && continue
  RESULTS=$(echo "$UPDATES" | jq -c '.result[]' 2>/dev/null || true)
  [[ -z "$RESULTS" ]] && continue
  while IFS= read -r update; do
    UPDATE_ID=$(echo "$update" | jq -r '.update_id'); OFFSET=$((UPDATE_ID + 1))
    MSG=$(echo "$update" | jq -c '.message // .edited_message // empty' 2>/dev/null); [[ -z "$MSG" ]] && continue
    TEXT=$(echo "$MSG" | jq -r '.text // empty'); [[ -z "$TEXT" ]] && continue
    CHAT_ID=$(echo "$MSG" | jq -r '.chat.id')
    MSG_ID=$(echo "$MSG" | jq -r '.message_id')
    FROM_ID=$(echo "$MSG" | jq -r '.from.id')
    FROM_USER=$(echo "$MSG" | jq -r '.from.username // .from.first_name // "unknown"')
    if ! is_allowed "$FROM_ID"; then echo "telegram-bridge: dropped from $FROM_USER ($FROM_ID)"; continue; fi
    echo "telegram-bridge: message from $FROM_USER: ${TEXT:0:80}..."
    start_typing "$CHAT_ID" & TYPING_PID=$!
    TMPFILE=$(mktemp)
    claude --print --system-prompt-file "$SYSTEM_PROMPT_FILE" "$TEXT" > "$TMPFILE" 2>/dev/null
    CLAUDE_EXIT=$?
    kill "$TYPING_PID" 2>/dev/null; wait "$TYPING_PID" 2>/dev/null || true
    RESPONSE=$([[ $CLAUDE_EXIT -eq 0 ]] && cat "$TMPFILE" || echo "Sorry, I encountered an error.")
    rm -f "$TMPFILE"
    RESPONSE=$(echo "$RESPONSE" | sed -e '/^$/d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    echo "telegram-bridge: responding (${#RESPONSE} chars)"
    send_message "$CHAT_ID" "${RESPONSE:-Sorry, I could not generate a response.}" "$MSG_ID"
  done <<< "$RESULTS"
done
```

7. Write `~/claude-telegram-bot/start.sh` with the following content, then run `chmod +x ~/claude-telegram-bot/start.sh`:

```
#!/bin/bash
BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_NAME="claude-telegram"
LOG_DIR="$BOT_DIR/logs"
mkdir -p "$LOG_DIR"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then echo "Session '$SESSION_NAME' already running."; exit 0; fi
tmux new-session -d -s "$SESSION_NAME" -c "$BOT_DIR" "$BOT_DIR/bridge.sh 2>&1 | tee -a $LOG_DIR/bridge.log"
echo "Started Telegram bridge in tmux session '$SESSION_NAME'"
```

8. Start the bridge by running `bash ~/claude-telegram-bot/start.sh`, then wait 3 seconds and run `tail -5 ~/claude-telegram-bot/logs/bridge.log` to confirm it started. The log should show `telegram-bridge: starting as <botname>`.

9. Tell the user to send a message to their bot in Telegram. Run `tail -10 ~/claude-telegram-bot/logs/bridge.log` to confirm a message was received and a response was sent.

10. Ask the user if they want the bridge to auto-start on login. If yes, tell them to run the following in their terminal (Claude Code cannot write to LaunchAgents due to system permissions — they must run this themselves), replacing YOUR_USERNAME with the result of `whoami`:

```
cat > ~/Library/LaunchAgents/com.claude.telegram-bridge.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.claude.telegram-bridge</string>
    <key>ProgramArguments</key><array><string>/bin/bash</string><string>/Users/YOUR_USERNAME/claude-telegram-bot/start.sh</string></array>
    <key>WorkingDirectory</key><string>/Users/YOUR_USERNAME/claude-telegram-bot</string>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
    <key>StandardOutPath</key><string>/Users/YOUR_USERNAME/claude-telegram-bot/logs/launchd.log</string>
    <key>StandardErrorPath</key><string>/Users/YOUR_USERNAME/claude-telegram-bot/logs/launchd.log</string>
    <key>EnvironmentVariables</key><dict><key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string><key>HOME</key><string>/Users/YOUR_USERNAME</string></dict>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.claude.telegram-bridge.plist
```

11. Print this final summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Telegram Claude Bridge — Setup Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Your bot is live. DM it on Telegram to talk to Claude.

  /telegram-bridge:status  — check if bridge is running
  /telegram-bridge:start   — start the bridge
  /telegram-bridge:logs    — view recent activity
  /telegram-bridge:kill    — stop the bridge
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
