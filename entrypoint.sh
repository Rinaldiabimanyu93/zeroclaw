#!/bin/sh
set -e

CONFIG="/zeroclaw-data/.zeroclaw/config.toml"

# Inject OPENROUTER_API_KEY
if [ -n "$OPENROUTER_API_KEY" ]; then
  sed -i "s|api_key = \"\"|api_key = \"${OPENROUTER_API_KEY}\"|" "$CONFIG"
fi

# Inject SYSTEM_PROMPT (harus sebelum [gateway] section!)
if [ -n "$ZEROCLAW_SYSTEM_PROMPT" ]; then
  if ! grep -q "^system_prompt" "$CONFIG"; then
    sed -i "s|\[gateway\]|system_prompt = \"${ZEROCLAW_SYSTEM_PROMPT}\"\n\n[gateway]|" "$CONFIG"
  fi
fi

# Add Telegram channel config
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  if ! grep -q "\[channels_config.telegram\]" "$CONFIG"; then
    printf '\n[channels_config]\ncli = true\n\n[channels_config.telegram]\nbot_token = "%s"\ndm_policy = "open"\nallowed_users = ["*"]\n' "${TELEGRAM_BOT_TOKEN}" >> "$CONFIG"
  fi
fi

# Inject COMPOSIO_API_KEY
if [ -n "$COMPOSIO_API_KEY" ]; then
  if ! grep -q "^\[composio\]" "$CONFIG"; then
    printf '\n[composio]\nenabled = true\napi_key = "%s"\nentity_id = "default"\n' "${COMPOSIO_API_KEY}" >> "$CONFIG"
  fi
fi

echo "=== Config ready, starting ZeroClaw daemon ==="
exec zeroclaw daemon
