# EOR Test Environment

E2E and integration testing for [Endless Org Roam](https://github.com/cuttlefisch/endless-org-roam) across multiple Emacs distributions.

## Overview

This repo provides:

- **Fixture KBs** -- Two sample org-roam instances with known UUIDs for deterministic testing
- **Profile configs** -- Minimal Emacs configs for vanilla, Doom, and Spacemacs
- **Test scripts** -- Runner scripts that set up isolated test environments
- **E2E test suite** -- Elisp tests that exercise EOR with real org-roam databases
- **Federation demo** -- Non-interactive demo of cross-instance queries, linking, and search
- **CI matrix** -- GitHub Actions workflows testing across Emacs versions and distros

## Demo

The demo builds real org-roam databases from the fixture KBs, registers them in a federation, then exercises cross-instance queries, link resolution, and search — finishing with an ASCII map of the federated knowledge graph:

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│ ◈ work                      │     │ ◈ personal                  │
│   bbbbbbbb… · 3 nodes       │     │   aaaaaaaa… · 5 nodes       │
│─────────────────────────────│     │─────────────────────────────│
│   ● Delta Node              │     │   ● Alpha Node              │
│   ● Epsilon Node            │     │   ● Beta Node               │
│                             │     │   ● Gamma Node              │
│                             │     │   ● Subheading with content │
└─────────────────────────────┘     └─────────────────────────────┘
                           ╲            ╱
                          ╚══ EOR Federation ══╝
                         ◀── eor: links ──▶
```

### Running the demo locally

The demo runs in batch mode — it does **not** touch your Emacs config, org-roam databases, or any files outside a temporary directory. Everything is fully isolated and cleaned up on exit.

**Prerequisites:** Emacs 29.1+ with org-roam available. If you use Doom Emacs with org-roam installed, the demo auto-detects your straight.el packages (no network needed). Otherwise it bootstraps straight.el into a temp directory.

```bash
# Clone both repos side by side
git clone https://github.com/cuttlefisch/eor-test-env.git
git clone https://github.com/cuttlefisch/endless-org-roam.git

# Run the demo
cd eor-test-env
./scripts/demo.sh
```

Or point it at a specific Emacs:

```bash
./scripts/demo.sh --emacs=/usr/local/bin/emacs-30.1
```

If the repos aren't adjacent, set `EOR_PACKAGE_DIR`:

```bash
EOR_PACKAGE_DIR=~/src/eor/endless-org-roam ./scripts/demo.sh
```

### What happens

1. Copies fixture KBs into `/tmp` (your files are never touched)
2. Runs `org-roam-db-sync` to build real SQLite databases
3. Registers both instances in an isolated federation registry
4. Demonstrates cross-instance node lookup (query work KB from personal context)
5. Resolves `eor:` links — targeted, local-first, and federated fallback
6. Collects search candidates across all instances
7. Renders the ASCII knowledge graph map

The demo exits `0` on success, `1` on any failure — it also runs as a CI job to prevent bitrot.

## Quick Start (E2E tests)

```bash
# Clone both repos
git clone https://github.com/cuttlefisch/eor-test-env.git
git clone https://github.com/cuttlefisch/endless-org-roam.git

# Run vanilla profile tests
cd eor-test-env
./scripts/run-tests.sh --profile=vanilla
```

## CI Matrix

| Job           | Emacs Versions              | Frequency     |
|---------------|---------------------------|---------------|
| Vanilla E2E   | 29.4, 30.1, snapshot      | Every push/PR |
| Doom E2E      | 29.4, 30.1                | Every push/PR |
| Spacemacs E2E | 29.4, 30.1                | Every push/PR |
| Demo          | 30.1                      | Every push/PR |
| org-roam HEAD | 30.1                      | Weekly / manual |

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
  demo.sh                 -- Federation demo launcher (safe, fully isolated)
  demo.el                 -- Demo Elisp: DB build, queries, links, graph map
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
