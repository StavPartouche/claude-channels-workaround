---
description: Guided first-time setup of the Telegram Claude bridge (workaround for API-based Claude subscriptions)
allowed-tools: [Bash, Write]
---

# Telegram Bot Setup

This sets up the Claude Code Telegram bridge — a bash script that polls Telegram and pipes messages to `claude --print`. It works for API-based Claude subscriptions where the official `--channels` flag returns "Channels are not currently available".

Walk the user through each step one at a time. Wait for confirmation before moving to the next step. If something fails, troubleshoot before continuing.

---

## Step 1 — Check prerequisites

Run these checks and report results:

```bash
claude --version 2>/dev/null || echo "MISSING: claude not found"
curl --version 2>/dev/null | head -1 || echo "MISSING: curl not found"
jq --version 2>/dev/null || echo "MISSING: jq not found"
tmux -V 2>/dev/null || echo "MISSING: tmux not found"
```

If `jq` or `tmux` are missing and the user is on macOS, offer to install them:

```bash
brew install jq tmux
```

Once all prerequisites are present, confirm with the user and move on.

---

## Step 2 — Create a Telegram bot

Tell the user:

> 1. Open Telegram and search for **@BotFather**
> 2. Send `/newbot`
> 3. Choose a display name (e.g. "My Mac Bot")
> 4. Choose a username ending in `bot` (e.g. `mymac_claude_bot`)
> 5. BotFather will give you a token like `123456789:AAH...` — paste it here

Wait for the user to paste their bot token. Validate it looks like a Telegram token (digits, colon, alphanumeric string).

---

## Step 3 — Get your Telegram user ID

Store the token the user provided, then run:

```bash
TOKEN="<TOKEN_FROM_USER>"
curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates" | jq '.result[0].message.from | {id, username, first_name}'
```

If the result shows nulls, tell the user:

> Your bot has no messages yet. Open Telegram, find your bot by username, and send it `/start`. Then tell me when done.

Once the user confirms, re-run the curl command and extract the numeric `id` field. That is their Telegram user ID.

---

## Step 4 — Create config files

Create the directory and store the token:

```bash
mkdir -p ~/.claude/channels/telegram
echo "TELEGRAM_BOT_TOKEN=<TOKEN_FROM_USER>" > ~/.claude/channels/telegram/.env
chmod 600 ~/.claude/channels/telegram/.env
```

Create the allowlist with the user's Telegram ID:

```bash
cat > ~/.claude/channels/telegram/access.json << EOF
{
  "dmPolicy": "allowlist",
  "allowFrom": [
    "<USER_TELEGRAM_ID>"
  ],
  "groups": {},
  "pending": {}
}
EOF
```

---

## Step 5 — Create the bot directory and scripts

```bash
mkdir -p ~/claude-telegram-bot/logs
```

Create `~/claude-telegram-bot/CLAUDE.md`:

```
You are a helpful assistant responding via Telegram. Reply directly and concisely. Output only your answer, nothing else.
```

Create `~/claude-telegram-bot/bridge.sh` with this exact content:

```bash
#!/bin/bash
# Telegram <-> Claude Code bridge

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$HOME/.claude/channels/telegram/.env"
ACCESS_FILE="$HOME/.claude/channels/telegram/access.json"
SYSTEM_PROMPT_FILE="$BOT_DIR/CLAUDE.md"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

TOKEN="${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set. Add it to $ENV_FILE}"
API="https://api.telegram.org/bot${TOKEN}"

ALLOWED_IDS=()
if [[ -f "$ACCESS_FILE" ]]; then
  while IFS= read -r id; do
    ALLOWED_IDS+=("$id")
  done < <(python3 -c "import json; [print(x) for x in json.load(open('$ACCESS_FILE')).get('allowFrom', [])]" 2>/dev/null)
fi

if [[ ${#ALLOWED_IDS[@]} -eq 0 ]]; then
  echo "Warning: No allowed IDs in access.json. All messages will be dropped."
fi

is_allowed() {
  local sender_id="$1"
  for id in "${ALLOWED_IDS[@]}"; do
    [[ "$id" == "$sender_id" ]] && return 0
  done
  return 1
}

send_message() {
  local chat_id="$1"
  local text="$2"
  local reply_to="${3:-}"
  while [[ ${#text} -gt 4096 ]]; do
    local chunk="${text:0:4096}"
    text="${text:4096}"
    local payload
    payload=$(jq -n --arg cid "$chat_id" --arg t "$chunk" '{chat_id: $cid, text: $t}')
    if [[ -n "$reply_to" ]]; then
      payload=$(echo "$payload" | jq --arg rid "$reply_to" '. + {reply_parameters: {message_id: ($rid | tonumber)}}')
    fi
    curl -s -X POST "$API/sendMessage" -H "Content-Type: application/json" -d "$payload" > /dev/null
    reply_to=""
  done
  if [[ -n "$text" ]]; then
    local payload
    payload=$(jq -n --arg cid "$chat_id" --arg t "$text" '{chat_id: $cid, text: $t}')
    if [[ -n "$reply_to" ]]; then
      payload=$(echo "$payload" | jq --arg rid "$reply_to" '. + {reply_parameters: {message_id: ($rid | tonumber)}}')
    fi
    curl -s -X POST "$API/sendMessage" -H "Content-Type: application/json" -d "$payload" > /dev/null
  fi
}

start_typing() {
  local chat_id="$1"
  while true; do
    curl -s -X POST "$API/sendChatAction" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\":\"$chat_id\",\"action\":\"typing\"}" > /dev/null 2>&1
    sleep 4
  done
}

OFFSET=0
echo "telegram-bridge: starting poll loop as $(curl -s "$API/getMe" | jq -r '.result.username')"
echo "telegram-bridge: allowed IDs: ${ALLOWED_IDS[*]}"

while true; do
  UPDATES=$(curl -s --max-time 35 "$API/getUpdates?offset=${OFFSET}&timeout=30" 2>/dev/null || true)
  if [[ -z "$UPDATES" ]] || [[ "$(echo "$UPDATES" | jq -r '.ok' 2>/dev/null)" != "true" ]]; then
    sleep 2
    continue
  fi
  RESULTS=$(echo "$UPDATES" | jq -c '.result[]' 2>/dev/null || true)
  if [[ -z "$RESULTS" ]]; then
    continue
  fi
  while IFS= read -r update; do
    UPDATE_ID=$(echo "$update" | jq -r '.update_id')
    OFFSET=$((UPDATE_ID + 1))
    MSG=$(echo "$update" | jq -c '.message // .edited_message // empty' 2>/dev/null)
    [[ -z "$MSG" ]] && continue
    TEXT=$(echo "$MSG" | jq -r '.text // empty')
    [[ -z "$TEXT" ]] && continue
    CHAT_ID=$(echo "$MSG" | jq -r '.chat.id')
    MSG_ID=$(echo "$MSG" | jq -r '.message_id')
    FROM_ID=$(echo "$MSG" | jq -r '.from.id')
    FROM_USER=$(echo "$MSG" | jq -r '.from.username // .from.first_name // "unknown"')
    if ! is_allowed "$FROM_ID"; then
      echo "telegram-bridge: dropped message from $FROM_USER ($FROM_ID) - not in allowlist"
      continue
    fi
    echo "telegram-bridge: message from $FROM_USER: ${TEXT:0:80}..."
    start_typing "$CHAT_ID" &
    TYPING_PID=$!
    TMPFILE=$(mktemp)
    claude --print \
      --system-prompt-file "$SYSTEM_PROMPT_FILE" \
      "$TEXT" > "$TMPFILE" 2>/dev/null
    CLAUDE_EXIT=$?
    kill "$TYPING_PID" 2>/dev/null
    wait "$TYPING_PID" 2>/dev/null || true
    if [[ $CLAUDE_EXIT -eq 0 ]]; then
      RESPONSE=$(cat "$TMPFILE")
    else
      RESPONSE="Sorry, I encountered an error processing your message."
    fi
    rm -f "$TMPFILE"
    RESPONSE=$(echo "$RESPONSE" | sed -e '/^$/d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    echo "telegram-bridge: responding (${#RESPONSE} chars)"
    if [[ -n "$RESPONSE" ]]; then
      send_message "$CHAT_ID" "$RESPONSE" "$MSG_ID"
    else
      send_message "$CHAT_ID" "Sorry, I could not generate a response." "$MSG_ID"
    fi
  done <<< "$RESULTS"
done
```

Create `~/claude-telegram-bot/start.sh`:

```bash
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
```

Make both scripts executable:

```bash
chmod +x ~/claude-telegram-bot/bridge.sh ~/claude-telegram-bot/start.sh
```

---

## Step 6 — Start the bridge

```bash
bash ~/claude-telegram-bot/start.sh
sleep 3
tail -5 ~/claude-telegram-bot/logs/bridge.log
```

The log should show: `telegram-bridge: starting poll loop as <botname>`

---

## Step 7 — Test it

Tell the user:

> Send any message to your bot in Telegram. You should see "typing..." and then a response from Claude.

Watch logs for confirmation:

```bash
tail -10 ~/claude-telegram-bot/logs/bridge.log
```

---

## Step 8 — Auto-start on login (macOS, optional)

Ask the user if they want the bridge to start automatically after every reboot.

If yes, tell them to run this in their terminal (Claude Code cannot write to LaunchAgents due to permissions):

```
cat > ~/Library/LaunchAgents/com.claude.telegram-bridge.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.telegram-bridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/YOUR_USERNAME/claude-telegram-bot/start.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/claude-telegram-bot</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/claude-telegram-bot/logs/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/claude-telegram-bot/logs/launchd.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/Users/YOUR_USERNAME</string>
    </dict>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.claude.telegram-bridge.plist
```

Remind them to replace `YOUR_USERNAME` with their actual macOS username (run `whoami` to check).

---

## Done

Print a final summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Telegram Claude Bridge — Setup Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Your bot is live. DM it on Telegram to talk to Claude.

  Useful commands:
    /telegram-bridge:status  — check if bridge is running
    /telegram-bridge:start   — start the bridge
    /telegram-bridge:logs    — view recent activity
    /telegram-bridge:kill    — stop the bridge

  Troubleshooting:
    - Bot doesn't respond → check logs with /telegram-bridge:logs
    - claude --print "hello" must work in your terminal
    - Your Telegram user ID must be in ~/.claude/channels/telegram/access.json
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
