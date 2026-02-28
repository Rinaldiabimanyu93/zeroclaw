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
    sed -i "s|\[gateway\]|system_prompt = \"${ZEROCLAW_SYSTEM_PROMPT}\"\n\n[gateway]|" "$CONFIG"
  fi
fi

# Add Telegram channel config
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  if ! grep -q "\[channels_config.telegram\]" "$CONFIG"; then
    printf '\n[channels_config]\ncli = true\n\n[channels_config.telegram]\nbot_token = "%s"\ndm_policy = "open"\nallowed_users = ["*"]\n' "${TELEGRAM_BOT_TOKEN}" >> "$CONFIG"
  fi
fi

# Inject Composio MCP via HTTP
if [ -n "$COMPOSIO_API_KEY" ]; then
  if ! grep -q "\[mcp\]" "$CONFIG"; then
    printf '\n[mcp]\n[[mcp.servers]]\nname = "composio"\ntransport = "http"\nurl = "https://backend.composio.dev/v3/mcp/44de0983-ba85-44e5-802f-fe06e0113fff/mcp?user_id=pg-test-b9f8d056-65c3-44ac-8a6b-540a1dc4c1ea"\nheaders = { x-api-key = "%s" }\n' "${COMPOSIO_API_KEY}" >> "$CONFIG"
  fi
fi

echo "=== Config ready, starting ZeroClaw daemon ==="
exec zeroclaw daemon
