# CRITICAL: No Credentials in Git

**NEVER commit, stage, or include any of the following in any branch, commit, or PR:**
- Private keys (`.pem`, `.p8`, `.p12`, `.key`)
- Service account JSON files (`service-account*.json`)
- Keystore files (`.jks`, `.keystore`)
- `.env` files containing secrets
- API keys, tokens, passwords, or any credential material

**All secrets MUST be stored as GitHub Secrets and restored at build time via CI/CD workflows.**

Before every commit, verify no sensitive files are staged:
```
git diff --cached --name-only | grep -iE '\.(pem|p8|p12|key|jks|keystore)$|service-account|\.env$'
```

If this returns any results, **DO NOT commit**. Remove them from staging with `git rm --cached <file>`.
