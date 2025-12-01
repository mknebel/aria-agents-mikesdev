#!/usr/bin/env bash
# Minimal helper to exercise OpenRouter chat completions from the CLI.
set -euo pipefail

PROMPT=${1:-"Return the current date formatted YYYY-MM-DD."}
MODEL_OVERRIDE=${OPENROUTER_MODEL:-}
if [[ $# -ge 2 && -n "$2" ]]; then
  MODEL_OVERRIDE=$2
fi
export MODEL_OVERRIDE
DEFAULT_MODELS='["qwen/qwen3-coder","inception/mercury-coder","morph/morph-v3-fast","morph/morph-v3-large","openai/gpt-oss-20b"]'
MODELS_JSON=${OPENROUTER_MODELS:-$DEFAULT_MODELS}
DEFAULT_PROVIDER_PREFS='{"only":["hyperbolic","deepinfra"],"order":["hyperbolic","deepinfra"],"sort":"throughput","allow_fallbacks":true}'
PROVIDER_PREFS_JSON=${OPENROUTER_PROVIDER_PREFS:-$DEFAULT_PROVIDER_PREFS}
SYSTEM_PROMPT=${OPENROUTER_SYSTEM_PROMPT:-"First decide whether tool usage is the optimal path for this task; if tool coordination is the best option, have Qwen3 handle planning and tool calls. Otherwise, use Qwen3 for complex coding plans and hand off to gpt-oss-20b for lighter implementation once planning is complete."}
DEFAULT_MODEL=${OPENROUTER_DEFAULT_MODEL:-qwen/qwen3-coder}
STREAM_PREF=${OPENROUTER_STREAM:-false}
BASE_URL=${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}
API_URL="$BASE_URL/chat/completions"

# Try to hydrate OPENROUTER_API_KEY from the standard config path if missing.
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  KEY_FILE="$HOME/.config/openrouter/api_key"
  if [[ -f "$KEY_FILE" ]]; then
    OPENROUTER_API_KEY=$(<"$KEY_FILE")
    export OPENROUTER_API_KEY
  fi
fi

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "Missing OPENROUTER_API_KEY. Set the env var or create ~/.config/openrouter/api_key" >&2
  exit 1
fi

REFERER_HEADER="${OPENROUTER_HTTP_REFERER:-https://local.codex.launch}"
TITLE_HEADER="${OPENROUTER_X_TITLE:-GlobalAgents Codex}"

build_payload() {
  python3 - <<'PY'
import json
import os

prompt = os.environ["PROMPT"]
provider_prefs_json = os.environ.get("PROVIDER_PREFS_JSON", "").strip()
system_prompt = os.environ.get("SYSTEM_PROMPT", "").strip()
stream_pref = os.environ.get("STREAM_PREF", "").strip().lower()
target_model = os.environ.get("TARGET_MODEL", "").strip()

if not target_model:
    raise SystemExit("TARGET_MODEL not provided")

manual_instructions = os.environ.get("MANUAL_INSTRUCTIONS", "").strip()
instruction_text = prompt
code_text = ""
update_text = ""

if manual_instructions:
    parts = {}
    current = None
    for line in manual_instructions.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            current = key.strip().lower()
            parts[current] = value.strip()
        elif current:
            parts[current] += "\n" + line
    instruction_text = parts.get("instruction", manual_instructions)
    code_text = parts.get("code", "")
    update_text = parts.get("update", "")
is_morph = target_model.startswith("morph/")

if is_morph:
    payload = {
        "model": target_model,
        "prompt": instruction_text,
        "input": {
            "instruction": instruction_text,
            "code": code_text,
            "update": update_text
        }
    }
else:
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})
    payload = {"model": target_model, "messages": messages}

if provider_prefs_json:
    try:
        provider_prefs = json.loads(provider_prefs_json)
        if isinstance(provider_prefs, dict):
            payload["provider"] = provider_prefs
    except json.JSONDecodeError:
        pass

if stream_pref in {"true", "1", "yes"}:
    payload["stream"] = True
else:
    payload["stream"] = False

print(json.dumps(payload))
PY
}

build_models_list() {
  python3 - <<'PY'
import json
import os

models_json = os.environ.get('MODELS_JSON', '').strip()
override = os.environ.get('MODEL_OVERRIDE', '').strip()

if override:
    print(override)
else:
    try:
        models = json.loads(models_json) if models_json else []
        if isinstance(models, list):
            for m in models:
                print(m)
    except json.JSONDecodeError:
        for part in (item.strip() for item in models_json.split(',')):
            if part:
                print(part)
PY
}

mapfile -t MODEL_CANDIDATES < <(build_models_list)

if [[ ${#MODEL_CANDIDATES[@]} -eq 0 ]]; then
  MODEL_CANDIDATES=()
  MODEL_CANDIDATES+=("$DEFAULT_MODEL")
fi

response=""
selected_model=""
for candidate in "${MODEL_CANDIDATES[@]}"; do
  payload=$(PROMPT="$PROMPT" PROVIDER_PREFS_JSON="$PROVIDER_PREFS_JSON" SYSTEM_PROMPT="$SYSTEM_PROMPT" STREAM_PREF="$STREAM_PREF" TARGET_MODEL="$candidate" build_payload)
  response=$(curl -sS "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "HTTP-Referer: ${REFERER_HEADER}" \
    -H "X-Title: ${TITLE_HEADER}" \
    -d "$payload")
  if command -v jq >/dev/null 2>&1; then
    if echo "$response" | jq -e 'has("error")' >/dev/null; then
      continue
    fi
  fi
  selected_model="$candidate"
  break
done

if [[ -z "$selected_model" ]]; then
  last_index=$(( ${#MODEL_CANDIDATES[@]} - 1 ))
  selected_model=${MODEL_CANDIDATES[$last_index]}
fi

if command -v jq >/dev/null 2>&1; then
  content=$(echo "$response" | jq -r '.choices[0].message.content // .choices[0].text // empty')
  model=$(echo "$response" | jq -r '.model // empty')
  provider=$(echo "$response" | jq -r '.provider // empty')
  prompt_tokens=$(echo "$response" | jq -r '.usage.prompt_tokens // empty')
  completion_tokens=$(echo "$response" | jq -r '.usage.completion_tokens // empty')
  total_tokens=$(echo "$response" | jq -r '.usage.total_tokens // empty')

  if [[ -z "$total_tokens" && $prompt_tokens =~ ^[0-9]+$ && $completion_tokens =~ ^[0-9]+$ ]]; then
    total_tokens=$((prompt_tokens + completion_tokens))
  fi

  [[ -n "$model" ]] || model="n/a"
  [[ -n "$provider" ]] || provider="n/a"
  [[ -n "$prompt_tokens" ]] || prompt_tokens="n/a"
  [[ -n "$completion_tokens" ]] || completion_tokens="n/a"
  [[ -n "$total_tokens" ]] || total_tokens="n/a"

  if [[ $selected_model == morph/* ]]; then
    if command -v jq >/dev/null 2>&1; then
      morph_summary=$(python3 - <<'PY'
import json
import os

manual = os.environ.get("MANUAL_INSTRUCTIONS", "").strip()
instruction = os.environ.get("PROMPT", "")
code = ""
update = ""

if manual:
    parts = {}
    current = None
    for line in manual.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            current = key.strip().lower()
            parts[current] = value.strip()
        elif current:
            parts[current] += "\n" + line
    instruction = parts.get("instruction", instruction)
    code = parts.get("code", "")
    update = parts.get("update", "")

print(json.dumps({"instruction": instruction, "code": code, "update": update}))
PY
      )
      instruction=$(echo "$morph_summary" | jq -r '.instruction')
      code=$(echo "$morph_summary" | jq -r '.code')
      update=$(echo "$morph_summary" | jq -r '.update')
      code=${code#$'\n'}
      update=${update#$'\n'}
      content=$(printf 'Morph applied the requested edit.\nInstruction: %s\n\nOriginal code:\n%s\n\nUpdated code:\n%s' "$instruction" "$code" "$update")
    else
      content="Morph applied the requested edit."
    fi
  fi

  if [[ -n "$content" ]]; then
    echo "Model    : $model"
    echo "Provider : $provider"
    echo "Tokens   : total=$total_tokens (prompt=$prompt_tokens, completion=$completion_tokens)"
    echo
    echo "$content"
  else
    echo "$response"
  fi
else
  echo "$response"
fi
