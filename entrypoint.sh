#!/bin/sh
set -e

CONFIG="/zeroclaw-data/.zeroclaw/config.toml"

# Inject OPENROUTER_API_KEY
if [ -n "$OPENROUTER_API_KEY" ]; then
  sed -i "s|api_key = \"\"|api_key = \"${OPENROUTER_API_KEY}\"|" "$CONFIG"
fi

# Inject SYSTEM_PROMPT
if [ -n "$ZEROCLAW_SYSTEM_PROMPT" ]; then
  if ! grep -q "^system_prompt" "$CONFIG"; then
    printf '\nsystem_prompt = "%s"\n' "${ZEROCLAW_SYSTEM_PROMPT}" >> "$CONFIG"
  fi
fi

# Add Telegram channel config
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  if ! grep -q "\[channels_config.telegram\]" "$CONFIG"; then
    printf '\n[channels_config]\ncli = true\n\n[channels_config.telegram]\nbot_token = "%s"\ndm_policy = "open"\nallowed_users = ["*"]\n' "${TELEGRAM_BOT_TOKEN}" >> "$CONFIG"
  fi
fi

echo "=== Config ready, starting ZeroClaw daemon ==="
exec zeroclaw daemon
