# Security policy

## Supported versions

Only the `main` branch is maintained. Fixes are not backported.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
**Security → Report a vulnerability** on this repository
([direct link](https://github.com/a-3isa/zyntro_flutter/security/advisories/new)).

Please do not open a public issue for a security problem.

Include what you can of:
- the screen, Firestore path, rule or Cloud Function affected;
- steps to reproduce, or a proof of concept;
- the impact you expect.

I aim to acknowledge reports within a week. Once an issue is confirmed, a fix is
prepared on a private branch and you are credited in the advisory unless you prefer not to be.

## Scope

In scope: the app, the Firestore and Storage rules in `firebase/`, and the Cloud
Functions in `functions/`.

Out of scope: findings that need a stolen account or device, denial of service by
volume, Firebase and Stripe themselves, and the Firebase client API keys in
`lib/firebase_options.dart`, which identify the project to the app and are public by
design.
