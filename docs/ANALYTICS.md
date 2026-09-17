# Analytics ownership and budgets

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-OBS-002

## Decision

| Pipeline | Role | Primary? | Retention / budget |
| --- | --- | --- | --- |
| Firebase Analytics (GA4) | Product analytics (screens, funnels, consent-gated) | **Yes** | Google Analytics retention defaults; respect in-app consent (`PrivacyConsentService`) |
| Firestore `analytics` | Session / resume / paired operational telemetry | No (secondary) | Cap client event types to session lifecycle only; prefer aggregation over raw dumps; review monthly write volume |
| Firestore `ops/heartbeats/jobs/*` | Schedule liveness | N/A | Tiny fixed docs; alert if `lastRunAt` older than 45 minutes |

Do **not** duplicate GA4 funnels into Firestore `analytics`. New product events go to GA4 only. Firestore writes stay limited to constitution/session observability events already defined in `SessionAnalyticsService`.

## Schedule heartbeats

These Cloud Functions must call `writeScheduleHeartbeat` on every invocation (including empty work):

- `expireStalePairedInvites`
- `expireStaleSessions`
- `expireStaleJointPostDrafts`

Operators should alert when any heartbeat is older than **45 minutes** (3 missed 15-minute ticks).

## Cost guardrails

1. Enable a Firebase / GCP budget alert on Firestore writes for the project.
2. If `analytics` write rate grows beyond session lifecycle events, stop adding types and move aggregates to BigQuery export from GA4.
3. Crashlytics remains the crash primary; do not mirror crashes into Firestore.

## Verification

- Contract tests assert this ownership doc and heartbeat helper wiring.
