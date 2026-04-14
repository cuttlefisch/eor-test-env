# EOR Test Environment

E2E and integration testing for [Endless Org Roam](https://github.com/cuttlefisch/endless-org-roam) across multiple Emacs distributions.

## Overview

This repo provides:

- **Fixture KBs** -- Two sample org-roam instances with known UUIDs for deterministic testing
- **Profile configs** -- Minimal Emacs configs for vanilla, Doom, and Spacemacs
- **Test scripts** -- Runner scripts that set up isolated test environments
- **E2E test suite** -- Elisp tests that exercise EOR with real org-roam databases
- **CI matrix** -- GitHub Actions workflows testing across Emacs versions and distros

## Quick Start

```bash
# Clone both repos
git clone https://github.com/cuttlefisch/eor-test-env.git
git clone https://github.com/cuttlefisch/endless-org-roam.git

# Run vanilla profile tests
cd eor-test-env
./scripts/run-tests.sh --profile=vanilla
```

## CI Matrix

| Profile    | Emacs Versions     | Frequency |
|------------|-------------------|-----------|
| Vanilla    | 28.1, 29.4, 30.1, snapshot | Every push/PR |
| Doom       | 29.4, 30.1        | Every push/PR |
| Spacemacs  | 29.4, 30.1        | Every push/PR |
| org-roam HEAD | 29.4, 30.1, snapshot | Weekly (Monday) |

## Structure

```
profiles/
  vanilla/init.el         -- emacs -Q + straight.el bootstrap
  doom/                   -- Minimal Doom config (init.el, packages.el, config.el)
  spacemacs/.spacemacs    -- Minimal Spacemacs dotfile
fixtures/
  instance-a/             -- 4 nodes with known UUIDs + sentinel
  instance-b/             -- 2 nodes with known UUIDs + sentinel
  expected-registry.el    -- Expected registry state for assertions
scripts/
  run-tests.sh            -- Main runner: --profile=<name> or --all
  setup-profile.sh        -- Bootstrap a profile's dependencies
  cleanup.sh              -- Remove temp artifacts
tests/
  test-e2e-common.el      -- E2E framework + test suites
```

## Fixture Node IDs

### Instance A (`aaaaaaaa-1111-2222-3333-444444444444`)

| Node    | UUID                                     |
|---------|------------------------------------------|
| Alpha   | `a1000001-0000-0000-0000-000000000001`   |
| Beta    | `a1000002-0000-0000-0000-000000000002`   |
| Gamma   | `a1000003-0000-0000-0000-000000000003`   |
| (sub)   | `a1000003-0000-0000-0000-000000000004`   |

### Instance B (`bbbbbbbb-1111-2222-3333-444444444444`)

| Node    | UUID                                     |
|---------|------------------------------------------|
| Delta   | `b2000001-0000-0000-0000-000000000001`   |
| Epsilon | `b2000002-0000-0000-0000-000000000002`   |

## Version Bumping

Version is automatically bumped on merged PRs to `main` using conventional commit analysis:

- `feat!:` → major bump
- `feat:` → minor bump
- `fix:`, `docs:`, `test:`, etc. → patch bump

## Relationship to Unit Tests

| Layer | Location | Framework | Speed | Dependencies |
|-------|----------|-----------|-------|-------------|
| Unit  | `endless-org-roam/test/` | Buttercup | Fast (~12ms) | Mocked org-roam |
| E2E   | `eor-test-env/tests/`    | Custom runner | Slower | Real org-roam DBs |

## License

GPL-3.0-or-later
