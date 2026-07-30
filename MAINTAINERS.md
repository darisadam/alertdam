# Maintainers

The human-readable roster. [`.github/CODEOWNERS`](.github/CODEOWNERS) is the
machine-readable twin, and **CODEOWNERS wins** where the two disagree — it is
what `scripts/ci/review-policy.sh` reads to decide who may approve an outside
contributor's pull request. Update both together.

## Active

| Maintainer | Areas | Timezone |
|---|---|---|
| [@darisadam](https://github.com/darisadam) | Everything | UTC+7 (Asia/Jakarta) |

## Emeritus

None yet.

## Areas looking for maintainers

Help in these areas would be genuinely useful — the current maintainer cannot
meaningfully cover them alone:

- **Flutter / iOS.** Critical Alerts require a special Apple entitlement, which
  needs an Apple Developer account and a real device to test against. There is
  currently no way to verify this end to end.
- **Flutter / Android.** Full-volume notification channels and Do Not Disturb
  bypass behave differently across OEM Android skins; a matrix of real devices is
  the only reliable way to test it.
- **Windows.** The backend cross-compiles for Windows but nobody runs it there.
- **Kubernetes.** `deploy/k8s/` is a placeholder. A Helm chart or Kustomize base
  from someone who actually operates AlertDam on a cluster would be better than
  one written speculatively.
- **Integrations.** Each chat platform needs someone with a live workspace to
  test against. See the integration request issue form.

See [GOVERNANCE.md](GOVERNANCE.md#becoming-a-maintainer) for how maintainership
works.
