# .github
A repo for organization-wide configuration.

## PULL_REQUEST_TEMPLATE.md

Global PR template. This must be followed for auditing purposes.  
Teams may only set specific PR templates that deviate from this template with proper approval.

## org-workflows/

Workflows applied across the entire organization via **Required Workflows**
(Org Settings → Actions → Required workflows). Each workflow must be registered
there by an org admin, pointing at `collibra/.github/<path>@main`.

| File                                              | Purpose                                                           |
|---------------------------------------------------|-------------------------------------------------------------------|
| `.githuub/workflows/enforce-codeowners-teams.yml` | Rejects CODEOWNERS entries that name individuals instead of teams |

## .github/workflows/

Regular workflows that run only within this repository (e.g. CI for the scripts
in `scripts/`).

## scripts/

Shell scripts used by the workflows in `org-workflows/`, with BATS tests alongside them.
Run tests locally with:

```sh
bats scripts/check-codeowners.bats
```
