# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| `main` (latest) | ✅ |
| Older releases | ⚠️ Best effort |

---

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities through public GitHub Issues.**

If you discover a security vulnerability, please use one of the following channels:

1. **GitHub Private Vulnerability Reporting** (preferred):
   Navigate to [Security → Advisories](https://github.com/darisadam/PagerDam/security/advisories/new) and click **"Report a vulnerability"**.

2. **Email:** Send details to the maintainer via the email listed on their [GitHub profile](https://github.com/darisadam).

---

## What to Include

Please provide as much detail as possible:

- **Description:** What is the vulnerability? What does it allow an attacker to do?
- **Steps to Reproduce:** A minimal, reproducible example
- **Impact:** Potential severity and affected components
- **Suggested Fix** (optional): If you have ideas for a fix

---

## Response Timeline

| Stage | Timeline |
|---|---|
| Initial acknowledgment | Within **48 hours** |
| Triage and severity assessment | Within **5 business days** |
| Fix and coordinated disclosure | Typically **30–90 days** depending on severity |

We follow a **responsible disclosure** model. We ask that you do not publicly disclose the vulnerability until we have released a patch.

---

## Security Best Practices for Self-Hosters

- Always use a strong, unique `JWT_SECRET` (minimum 64 characters)
- Keep your PostgreSQL instance firewalled and not publicly accessible
- Run PagerDam behind a TLS-terminating reverse proxy (Nginx, Caddy, Traefik)
- Rotate your integration tokens (Slack, Discord, Twilio) regularly
- Enable `secret_scanning_push_protection` on your forks (already enabled on this repo)
- Run `make secrets-scan` before committing to catch accidental credential leaks
