# Security Checklist (Optional)

**Purpose:** Quick security review checklist. Adapt for your project. For full audits, use a dedicated DevSecOps workflow.

---

## Egress & PII

- [ ] All external API calls scrub or validate PII before send
- [ ] Secrets (API keys, tokens) never logged or committed
- [ ] Reversible PII maps not persisted to cloud

## Auth & Secrets

- [ ] Auth enforced server-side for sensitive operations
- [ ] API keys in env vars or secure secrets (not in repo)
- [ ] Token refresh and expiry handled correctly

## Input & Storage

- [ ] User input validated/sanitized (injection, path traversal)
- [ ] Sensitive data at rest uses secure storage (Keychain, etc.)
- [ ] Backup/export excludes secrets and reversible maps

## Logging & Debug

- [ ] Production logs don't contain PII, tokens, or raw keys
- [ ] Debug prints guarded with release-mode checks

## Dependencies

- [ ] Known vulnerable dependencies updated
- [ ] Dependency scanning in CI (e.g. `npm audit`, `dart pub outdated`)
