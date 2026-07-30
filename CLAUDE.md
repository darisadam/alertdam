# AlertDam — Claude Code instructions

@AGENTS.md

The import above is the whole of this project's agent policy. It is imported
rather than duplicated so the two cannot drift apart — if you find yourself
about to add a rule here, add it to `AGENTS.md` instead.

## The one rule most likely to conflict with your defaults

Claude Code appends `Co-Authored-By: Claude ...` to commits and
"🤖 Generated with [Claude Code]" to pull request bodies by default.

**This repository rejects both.** The `commit-msg` git hook and the
`Conventions` required status check will fail the commit or the PR. See the
commit policy in `AGENTS.md` for the reasoning and for where to disclose AI
assistance instead.

## Quick reference

```sh
make setup    # install dev deps and git hooks
make verify   # the exact checks CI runs — run before proposing a commit
```

Never commit to `main`. Branch as `<type>/<kebab-description>`, open a PR, and
make the PR title a valid Conventional Commit — it becomes the commit message on
`main`.
