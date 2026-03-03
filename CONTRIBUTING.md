# Contributing to Bars Bookkeeper Manager

This app is tightly coupled to the Bars Bookkeeper backend API:
- Backend repo: https://github.com/theos2node/The-Bars-Bookkeeper
- iPad app repo: this repository

Use this guide to make changes safely and keep both repos organized.

## 1. Local Setup

1. Open `BarsBookkeeperManager.xcodeproj` in Xcode.
2. Use Xcode 15+ and an iOS 17+ simulator.
3. Set your signing team if needed.
4. Sign in with a non-production account if possible.

## 2. Branch and PR Workflow

1. Create a focused branch per change.
2. Keep PRs small and scoped to one feature/fix.
3. In PR description, include:
   - what changed
   - why it changed
   - risk areas
   - manual verification steps
4. If API contracts changed, link the backend PR.

## 3. Required Verification Before Merge

Run build:

```bash
xcodebuild -project "BarsBookkeeperManager.xcodeproj" \
  -scheme "BarsBookkeeperManager" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Manual app checks:

1. Login + logout flow works.
2. Inventory list loads, search works, detail panel opens.
3. Requests load; accept/deny actions work.
4. Predictions load; run forecast works for manager/owner.
5. Orders load; generate/send/update paths still work.
6. Settings profile/password/tenant updates work.
7. Base URL override in Settings still works.

## 4. API Contract Rules

The UI decodes backend JSON directly via `Codable` model structs. Renames or type changes can crash decoding.

Before merging API-related changes:

1. Check impacted structs in `BarsBookkeeperManager/Models/`.
2. Check endpoint usage in `BarsBookkeeperManager/Services/APIService.swift`.
3. Keep existing JSON keys stable when possible.
4. If a key must change, update app model + UI in the same initiative.
5. Prefer additive backend changes over destructive changes.

See `docs/API_COMPATIBILITY.md` for current endpoint/field dependencies.

## 5. UI and State Guidelines

1. Keep network calls in `APIService` and view-level orchestration in views.
2. Keep auth/session logic in `AuthService`.
3. Avoid duplicating business logic across views; prefer model computed properties.
4. Keep new shared UI in `Views/Components/` and theme values in `Theme/Theme.swift`.

## 6. Security and Secrets

1. Never hardcode credentials, API tokens, or tenant secrets.
2. Auth token storage belongs in `KeychainService`.
3. Do not log bearer tokens.

## 7. Documentation Expectations

Update docs when behavior changes:

1. `README.md` for setup/feature-level changes.
2. `docs/ARCHITECTURE.md` when structure/data flow changes.
3. `docs/API_COMPATIBILITY.md` when endpoint or model contracts change.
4. `docs/REPO_STRATEGY.md` when team workflow/repo strategy changes.

## 8. CI and Integration Checks

1. App build CI runs from `.github/workflows/ios-ci.yml`.
2. Backend contract smoke checks run from `.github/workflows/backend-contract-smoke.yml`.
3. Configure these GitHub Actions secrets for smoke checks:
   - `API_BASE_URL` (include `/api`)
   - `API_TEST_EMAIL`
   - `API_TEST_PASSWORD`
4. Smoke script path: `scripts/api_contract_smoke.sh`.
