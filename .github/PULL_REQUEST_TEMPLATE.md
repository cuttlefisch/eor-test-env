## Summary

<!-- What does this PR do? Keep it to 1-3 bullet points. -->

## Motivation

<!-- Why is this change needed? Link to issues if applicable. -->

## Changes

<!-- List the key changes. -->

## Version bump

<!-- Add ONE of these labels to control the release version: -->
<!-- release:patch — bug fixes, docs, CI tweaks (0.1.0 → 0.1.1) -->
<!-- release:minor — new test suites, profiles, fixtures (0.1.0 → 0.2.0) -->
<!-- release:major — breaking changes to test framework (0.1.0 → 1.0.0) -->
<!-- If no label is set, the bump is inferred from commit messages. -->

## Test plan

- [ ] E2E tests pass locally (`./scripts/run-tests.sh --profile=vanilla`)
- [ ] Demo runs successfully (`./scripts/demo.sh`)
- [ ] Manual verification (describe what you tested, or N/A):

```
<!-- Example: -->
<!-- 1. Added new fixture node to instance-a -->
<!-- 2. Ran demo.sh and verified new node appears in federation map -->
<!-- 3. Ran E2E tests, all 10 pass with 31+ assertions -->
```

## PR checklist

- [ ] Conventional commit messages used (`feat:`, `fix:`, `docs:`, `test:`, `ci:`)
- [ ] Version bump label applied (`release:patch`, `release:minor`, or `release:major`)
- [ ] No sensitive data in fixtures (no real UUIDs, paths, or credentials)
