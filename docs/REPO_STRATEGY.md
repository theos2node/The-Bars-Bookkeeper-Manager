# Repo Strategy: Keep Split Repos, Add Tight Integration

Recommendation: keep the backend and iPad app in separate repos, and enforce integration through CI and contract checks.

## Why This Is Better Than Merging Right Now

1. Different stacks and release cadences:
   - Backend (server-side)
   - iPad app (Xcode/iOS)
2. Cleaner ownership and smaller PR blast radius.
3. Faster contributor onboarding when responsibilities stay clear.
4. You still get seamless behavior if contracts are tested continuously.

## What Makes It Seamless

1. App CI build on every push/PR:
   - `.github/workflows/ios-ci.yml`
2. Scheduled/backend smoke checks for critical endpoints:
   - `.github/workflows/backend-contract-smoke.yml`
   - `scripts/api_contract_smoke.sh`
3. Explicit API contract mapping:
   - `docs/API_COMPATIBILITY.md`
4. Contributor guardrails and QA checklist:
   - `CONTRIBUTING.md`
   - `.github/pull_request_template.md`

## If You Still Want a Monorepo Later

Only do it after:

1. API contracts are stable and versioned.
2. Team agrees on one shared CI pipeline strategy.
3. You define clear folder ownership and CODEOWNERS rules.
4. You confirm mobile release workflow won’t be slowed by backend-only changes.

Until then, split repo + contract automation is the lower-risk path.

