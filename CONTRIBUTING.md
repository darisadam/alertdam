# Contributing to PagerDam

Thank you for your interest in contributing to PagerDam! 🎉

This document outlines the conventions and processes to follow when contributing.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Branching Model](#branching-model)
- [Commit Conventions](#commit-conventions)
- [Pull Request Process](#pull-request-process)
- [Development Setup](#development-setup)
- [Testing](#testing)

---

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please treat all contributors with respect and create a welcoming environment.

---

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PagerDam.git
   cd PagerDam
   ```
3. **Add upstream** remote:
   ```bash
   git remote add upstream https://github.com/darisadam/PagerDam.git
   ```
4. **Set up** your local environment:
   ```bash
   make setup
   cp .env.example .env
   # Edit .env with your local values
   ```

---

## Branching Model

We use a simplified **GitHub Flow** model:

| Branch | Purpose |
|---|---|
| `main` | Production-ready code. Always deployable. Protected. |
| `feat/xxx` | New features |
| `fix/xxx` | Bug fixes |
| `chore/xxx` | Maintenance tasks (deps, refactor, CI) |
| `docs/xxx` | Documentation changes |

**Rules:**
- Never commit directly to `main`
- Always branch off the latest `main`
- Keep branches short-lived and focused on a single concern

```bash
# Sync your main with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create your feature branch
git checkout -b feat/slack-thread-support
```

---

## Commit Conventions

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

**Format:**
```
<type>(<scope>): <short description>

[optional body]

[optional footer: Closes #issue]
```

**Types:**

| Type | When to use |
|---|---|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only changes |
| `style` | Formatting (no logic change) |
| `refactor` | Code change with no feature/fix |
| `test` | Adding or fixing tests |
| `chore` | Build process, dependencies, CI |
| `perf` | Performance improvement |

**Examples:**
```bash
git commit -m "feat(slack): add acknowledge button to alert cards"
git commit -m "fix(escalation): prevent duplicate notifications on retry"
git commit -m "docs: add self-hosting guide to README"
git commit -m "chore(deps): upgrade go to 1.23"
```

---

## Pull Request Process

1. Ensure your branch is up to date with `main`
2. Make sure all tests pass: `make test`
3. Run the linter: `make lint`
4. Fill in the **PR template** completely
5. Link the related issue: `Closes #123`
6. Request at least **1 review** from a maintainer
7. All status checks must pass before merging
8. We use **squash merging** — your PR title becomes the commit message on `main`

---

## Development Setup

### Backend (Go)
```bash
cd backend
go mod download
go run ./cmd/pagerdam/... # Start the server
```

### Web Dashboard (React)
```bash
cd web
npm install
npm run dev
```

### Mobile App (Flutter)
```bash
cd mobile
flutter pub get
flutter run
```

### Full Stack (Docker)
```bash
make docker
# Dashboard: http://localhost:8080
```

---

## Testing

```bash
# Run all Go tests
make test

# Run with coverage report
make test-coverage

# Lint
make lint

# Secrets scan (requires gitleaks)
make secrets-scan
```

Please add tests for any new functionality you introduce. We aim for >80% code coverage on the backend.

---

## Questions?

Open a [GitHub Discussion](https://github.com/darisadam/PagerDam/discussions) or check existing [Issues](https://github.com/darisadam/PagerDam/issues).
