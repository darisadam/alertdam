# 0008. Deliver mobile push through the operator's own Firebase project

- **Status:** Proposed
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

Mobile push has a constraint that no amount of engineering removes: FCM and
APNs deliver only to app builds signed against the credentials of the app's
*publisher*. A store-published "official AlertDam" app can only receive pushes
sent with the project's Firebase/APNs keys — which a self-hosted backend does
not have. This is why every self-hosted product with store apps (Grafana
OnCall, Home Assistant, Bitwarden, Zulip, Rocket.Chat) operates a hosted push
relay: the one piece of vendor infrastructure in an otherwise self-hosted
stack.

For v1.0.0 this project has no operational budget or on-call rotation to run a
relay that other people's pagers depend on. Running it badly would be worse
than not running it: the relay becomes the least-reliable link in everyone
else's alerting.

A second honesty problem: iOS **Critical Alerts** (bypassing silent/Focus)
require a per-app-ID entitlement that Apple grants case by case. No
architecture makes that automatic.

## Decision

1. **v1.0.0: bring your own Firebase.** The operator creates a free Firebase
   project, registers the Android and iOS apps, uploads their APNs key to
   Firebase, and builds the Flutter app themselves against that project. The
   documented distribution paths are TestFlight / Play internal track /
   sideload — team-scale distribution, not public stores.
2. **The backend sends through the FCM v1 HTTP API only**, authenticated with
   the operator's service-account JSON (`FIREBASE_CREDENTIALS_FILE`, already
   anticipated by `docker-compose.yml`). FCM carries the APNs payload for iOS,
   so there is exactly one sender implementation and one credential for the
   operator to manage.
3. **Interruption honesty on iOS**: the app requests Time-Sensitive by default
   (no entitlement needed) and enables Critical Alerts only when the
   operator's own app ID has been granted the entitlement. The build guide
   documents how to request it and does not promise approval. Server-driven
   re-notification until acknowledgement compensates on both platforms.
4. **Android** uses a max-importance notification channel with a DND-bypass
   request flow (user-grantable, no special approval needed).
5. **Repo deliverables**: the pairing/device-registry API, the FCM channel,
   fastlane lanes, and a step-by-step BYO Firebase build guide.
   `alertdam config check` validates the FCM credential with a dry-run send so
   misconfiguration is caught at deploy time, not at 3 AM.
6. **Phase 2 (hosted offering)**: project-published store apps plus an
   open-source, stateless push relay operated by the project. The mobile app
   is built now to take its push registration endpoint from configuration, so
   the relay slots in without an app rewrite.

## Consequences

### Positive

- 100% self-hosted push with zero project-run infrastructure and no
  availability promise the project cannot keep.
- Consistent with the product's BYOK stance (Twilio, SMTP) and free at
  team scale.
- One sender path (FCM v1) instead of separate FCM and APNs stacks.

### Negative

- Real setup friction: Firebase project, two app registrations, an APNs key,
  and a signed build. This is the price of the constraint; the mitigation is
  documentation quality, fastlane automation, and the credential dry-run
  check. Teams unwilling to pay it still get Slack/Telegram/email/voice.
- No public-store "install AlertDam" experience in v1. Deferred to Phase 2,
  not lost.
- Most operators will not obtain the Critical Alerts entitlement; their iOS
  ceiling is Time-Sensitive plus re-notification. Documented plainly.

### Neutral

- Degoogled-Android delivery (UnifiedPush/ntfy) is compatible with this model
  as an additional transport later; nothing in v1 forecloses it.

## Alternatives considered

**Project-hosted relay + store apps in v1.** The eventual right answer and the
industry norm, but it makes a volunteer-operated service a hard dependency of
other people's pagers on day one. Deferred until it can be run with real
on-call, monitoring, and a status page (Phase 2).

**Backend speaks APNs directly (BYO .p8) + FCM for Android.** Removes Firebase
from the iOS path but doubles the sender implementations and gives operators
two credentials to manage. FCM-carries-APNs is one credential and one code
path; direct APNs can be added later if operators ask.

**Web push / PWA instead of native apps.** No Critical/Time-Sensitive
semantics, unreliable in background on iOS, no DND bypass — inadequate for the
one job this app has, which is waking someone.

**WebSocket from app to backend, no push at all.** iOS will not keep the
socket alive in background; this only works as a foreground supplement (which
the app does use to live-update the incident list).
