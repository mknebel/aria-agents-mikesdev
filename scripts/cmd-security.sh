#!/bin/bash
# cmd-security.sh - Quick security scan
echo "=== Security Scan ==="

echo -e "\n1. Hardcoded Secrets:"
rg -i -n "(password|secret|api_key|private_key|access_token)\s*[=:]\s*['\"][^'\"]{8,}" --glob '!*.lock' --glob '!node_modules' --glob '!vendor' 2>/dev/null | head -10 || echo "None"

echo -e "\n2. SQL Injection:"
rg -n "(\$_(GET|POST|REQUEST)\[.*\].*query|execute\(.*\\\$)" --glob '*.php' 2>/dev/null | head -10 || echo "None"

echo -e "\n3. XSS:"
rg -n "(echo|print)\s+\\\$_(GET|POST|REQUEST)" --glob '*.php' 2>/dev/null | head -5 || echo "None (PHP)"
rg -n "innerHTML\s*=.*\\\$|v-html" --glob '*.{js,vue}' 2>/dev/null | head -5 || echo "None (JS)"

echo -e "\n4. Dangerous Functions:"
rg -n "(eval\(|exec\(|system\(|shell_exec\()" --glob '*.php' 2>/dev/null | head -5 || echo "None"

echo -e "\n5. Sensitive Files:"
for f in .env .env.local credentials.json secrets.json id_rsa *.pem; do
    [[ -f "$f" ]] && echo "WARNING: $f"
done

echo -e "\n6. Debug Mode:"
rg -n "(DEBUG\s*=\s*[Tt]rue|APP_DEBUG=true)" --glob '!*.example' 2>/dev/null | head -5 || echo "None"
