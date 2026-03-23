#!/bin/bash
# Telegram <-> Claude Code bridge
# Polls Telegram getUpdates, pipes messages to claude --print, sends response back.

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$HOME/.claude/channels/telegram/.env"
ACCESS_FILE="$HOME/.claude/channels/telegram/access.json"
SYSTEM_PROMPT_FILE="$BOT_DIR/CLAUDE.md"

# Load token from .env
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

TOKEN="${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set. Add it to $ENV_FILE}"
API="https://api.telegram.org/bot${TOKEN}"

# Load allowed user IDs from access.json
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
