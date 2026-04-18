---
on:
  workflow_run:
    workflows: ["test-libc"]
    types: [completed]
    branches:
      - ai
      - libc/**
      - libzigc-**
      - stdio-**
      - combined

permissions:
  contents: read
  actions: read
  issues: read
  pull-requests: read

if: ${{ github.event.workflow_run.conclusion == 'failure' }}

engine: copilot

tools:
  github:
    toolsets: [default, actions]
  bash: [":*"]

network: defaults

safe-outputs:
  create-issue:
    max: 1
    title-prefix: "[aw ci-triage] "
    labels: [libzigc, ci-failure, agentic-workflow, needs-triage]
---

# ci-failure-triage

Analyze a failed run of the `test-libc` workflow and open a concise
triage issue.

## Context

The `test-libc` workflow builds a stage4 Zig compiler from a given fork
branch, then runs `zig build test-libc` against 10 musl-libc targets
(x86_64, x86, aarch64, arm, thumb, riscv, powerpc, s390x, loongarch64,
wasm32). It is dispatched manually with `branch` + `test-filter` inputs.

Tracking issue: #10. Release-track branch: `libc/0.16.x`.

Event data you have access to:
- Workflow run ID: `${{ github.event.workflow_run.id }}`
- Head SHA under test: `${{ github.event.workflow_run.head_sha }}`
- Run URL: `${{ github.event.workflow_run.html_url }}`

Fetch the head branch name from the GitHub API using the run ID — it is
not exposed in the triggering payload.

## Task

1. Fetch the failed jobs from the run using the GitHub MCP `actions` toolset.
2. For each failed job, pull ~500 lines of tail log (`get_job_logs` with
   `tail_lines: 500`, `return_content: true`).
3. Identify **one** root cause. Common buckets:
   - Zig compiler crash / segfault (report as potential new #243-class bug)
   - libc test assertion failure (note which test, which target)
   - Build/link error in the Zig port itself (syntax, ABI, missing symbol)
   - Environment flake (runner OOM, thread exhaustion, timeout)
4. Open **one** issue. Title should be short and specific:
   `test-libc <branch> failed on <target>: <one-line symptom>`.
   Body should include:
   - Link to the run and the failing branch
   - The smallest useful log excerpt (under 30 lines)
   - Root-cause hypothesis
   - Suggested next step (one concrete action — do not enumerate options)

## Deduplication

Before filing, search existing open issues with label `ci-failure` for a
matching symptom. If there's a clear duplicate, skip filing — the issue
already exists.

## Do not

- Do not open more than one issue per run.
- Do not file an issue for cancelled, skipped, or success-after-retry runs.
- Do not push code. Do not open PRs.
- Do not propose elaborate fixes; leave that to the human.
