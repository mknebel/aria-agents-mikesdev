---
description: Quick security scan for common vulnerabilities
allowed-tools: Bash, Grep
---

Scan the project for common security issues.

```bash
echo "=== Security Scan ==="
echo ""

# Define patterns
echo "Scanning for potential security issues..."
echo ""

echo "=== 1. Hardcoded Secrets ==="
rg -i -n "(password|secret|api_key|apikey|private_key|access_token)\s*[=:]\s*['\"][^'\"]{8,}" --glob '!*.lock' --glob '!*.md' --glob '!node_modules' --glob '!vendor' 2>/dev/null | head -20 || echo "None found"

echo ""
echo "=== 2. SQL Injection Risks ==="
rg -n "(\$_(GET|POST|REQUEST|COOKIE)\[.*\].*query|execute\(.*\\\$|mysql_query.*\\\$)" --glob '*.php' 2>/dev/null | head -20 || echo "None found"

echo ""
echo "=== 3. XSS Vulnerabilities ==="
rg -n "(echo|print)\s+\\\$_(GET|POST|REQUEST)" --glob '*.php' 2>/dev/null | head -10 || echo "None found (PHP)"
rg -n "innerHTML\s*=\s*[^\"]*\\\$|v-html\s*=" --glob '*.{js,ts,vue,jsx,tsx}' 2>/dev/null | head -10 || echo "None found (JS)"

echo ""
echo "=== 4. Insecure Functions ==="
rg -n "(eval\(|exec\(|system\(|shell_exec\(|passthru\(|popen\()" --glob '*.php' 2>/dev/null | head -10 || echo "None found (PHP)"
rg -n "eval\(|new Function\(" --glob '*.{js,ts}' 2>/dev/null | head -10 || echo "None found (JS)"

echo ""
echo "=== 5. Sensitive Files ==="
for f in .env .env.local .env.production credentials.json secrets.json id_rsa *.pem *.key; do
    if [[ -f "$f" ]]; then
        echo "WARNING: Found sensitive file: $f"
    fi
done
echo "Check complete."

echo ""
echo "=== 6. Debug Mode in Production Files ==="
rg -n "(DEBUG\s*=\s*[Tt]rue|debug\s*:\s*true|APP_DEBUG=true)" --glob '!*.md' --glob '!*.example' 2>/dev/null | head -10 || echo "None found"

echo ""
echo "=== 7. .gitignore Check ==="
if [[ -f ".gitignore" ]]; then
    for pattern in ".env" "*.pem" "*.key" "credentials" "secrets"; do
        if ! grep -q "$pattern" .gitignore 2>/dev/null; then
            echo "WARNING: $pattern not in .gitignore"
        fi
    done
    echo ".gitignore check complete."
else
    echo "WARNING: No .gitignore file found!"
fi
```

After running the scan, summarize findings and provide specific remediation advice for any issues found.
