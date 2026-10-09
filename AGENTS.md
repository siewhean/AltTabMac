# AI Project Operating Rules

> Recommended repository-level instructions for AI agents working on a software project.
> Place this file at the repository root and adapt the project-specific sections as needed.

## 1. Core Principle

Work from verified reality, not assumptions.

Before making changes, inspect the current repository, branch, relevant documentation, open work, recent commits, CI state, deployment state, and any files that define the requested behavior.

Never claim that work, testing, deployment, review, approval, or verification happened unless it actually happened and there is evidence for it.

## 2. Source of Truth

Use this order of precedence when instructions conflict:

1. Explicit instructions from the current user/task.
2. Repository-level governance and architecture decisions.
3. Current implementation and tests.
4. Product specifications and roadmap documents.
5. Historical notes, old plans, stale tickets, and previous assumptions.

If two authoritative sources conflict, stop before making a consequential change and surface the conflict clearly.

Do not silently reinterpret requirements.

## 3. Start Every Task With a State Check

Before editing code:

- Pull or inspect the latest target branch.
- Confirm the exact current commit SHA.
- Check whether the branch moved since the task was written.
- Inspect relevant open pull requests and recent commits.
- Read the files directly related to the requested change.
- Check current CI and deployment state when the task affects release behavior.
- Identify existing tests, validators, runbooks, and architecture decisions.

Do not work from a stale SHA if the branch has changed.

## 4. Plan Before Editing

For non-trivial tasks, establish:

- Objective.
- In-scope files and systems.
- Out-of-scope areas.
- Existing behavior.
- Expected behavior.
- Risks.
- Validation plan.
- Rollback plan if the task affects production.

Prefer the smallest coherent change that solves the underlying problem.

Do not bundle unrelated cleanup, refactors, redesigns, and dependency upgrades into a focused fix unless explicitly requested.

## 5. Fix Causes, Not Symptoms

When something fails:

1. Reproduce or inspect the exact failure.
2. Identify the root cause.
3. Fix the root cause.
4. Add or update regression coverage.
5. Re-run the failed check.
6. Run surrounding checks that could be affected.

Do not:
- disable a failing test to make CI green;
- weaken thresholds without explicit approval;
- hard-code output solely to satisfy a validator;
- replace a real check with a mocked PASS;
- hide an environment mismatch by editing metadata.

## 6. Change Scope Discipline

Keep changes tightly aligned to the requested task.

Before modifying shared code, inspect where it is used.

If a seemingly small change has broad impact:
- identify the affected surfaces;
- explain the expansion in scope;
- test all affected behavior.

Avoid speculative refactors during release-critical work.

## 7. Exact Version and SHA Discipline

For release, certification, migration, or deployment work:

- Bind evidence to exact Git SHAs.
- Record the exact deployed SHA.
- Do not use ambiguous labels such as `latest` as release evidence.
- If code changes after qualification, treat the new SHA as a new candidate.
- Do not combine evidence from different SHAs into one certification.

If multiple services are independently versioned, explicitly record each service SHA.

## 8. Testing Rules

Run the narrowest relevant tests first, then broader tests.

Typical order:

1. Focused unit tests.
2. Package-level tests.
3. Typecheck.
4. Lint/format checks.
5. Integration tests.
6. Build.
7. Browser/end-to-end tests.
8. Accessibility/visual tests where applicable.
9. Production or staging smoke tests when deployment is involved.

Never report PASS when a required test was skipped, unavailable, or not executed.

Distinguish:
- `PASS`
- `FAIL`
- `BLOCKED`
- `NOT_RUN`
- `WAIVED_NOT_EXECUTED`

## 9. Evidence Integrity

Evidence must describe what actually occurred.

Never fabricate:
- human reviews;
- user interviews;
- physical-device testing;
- penetration tests;
- legal approvals;
- production incidents;
- external delivery confirmations;
- performance measurements;
- backup restores;
- failover drills.

Synthetic tests must be labeled synthetic.

Simulation results must not be presented as live production evidence.

If a required human or external activity cannot be performed, record it truthfully as pending, blocked, deferred, or waived according to project governance.

## 10. Security Rules

Never expose, print, commit, or paste:

- API keys;
- private tokens;
- passwords;
- database credentials;
- private certificates;
- signing keys;
- session cookies;
- personal secrets.

Use secret managers and environment variables.

When inspecting configuration, report sanitized destinations and setting names rather than secret values.

Do not weaken:
- authentication;
- authorization;
- rate limiting;
- CSP/security headers;
- tenant isolation;
- object-level access controls;
- encryption;
- audit logging;

unless the task explicitly requires an approved security-policy change.

## 11. Data and Migration Safety

For database changes:

- Use forward-compatible migrations where possible.
- Prefer expand-contract patterns.
- Inspect locking and table-scan implications.
- Verify old and new application versions can coexist when zero-downtime deployment is required.
- Never run destructive migrations casually.
- Never use production data for tests unless the workflow explicitly permits it.
- Back up before destructive operational work.

Verify migrations against a realistic database environment, not only syntax.

## 12. Production Safety

Before production changes:

- Verify current production state.
- Verify the intended release SHA.
- Verify current CI.
- Confirm environment and service targets.
- Confirm rollback path.
- Check database and cache targets.
- Verify staging and production isolation.

After production changes:

- Verify health.
- Verify release identity.
- Verify critical routes.
- Verify authentication boundaries.
- Inspect logs and runtime errors.
- Confirm staging remains intact if it is a separate environment.

Do not declare production healthy from a deployment dashboard alone.

## 13. Deployment Rules

A production deployment is complete only when:

- the intended artifact is deployed;
- the exact release identity is known;
- the application responds;
- critical dependencies are healthy;
- representative dynamic routes work;
- security boundaries still behave correctly;
- runtime logs show no unexplained errors.

Prefer promotion of a previously verified immutable artifact over rebuilding during release.

## 14. Branch and Pull Request Rules

Default workflow:

- Work on a dedicated branch unless the project explicitly uses direct-to-branch delivery.
- Keep commits focused and descriptive.
- Do not rewrite shared history without explicit approval.
- Re-check the target branch before merge.
- Use expected-head SHA protection for consequential merges when supported.

Before merging:
- required CI must be green;
- unresolved review issues must be addressed;
- the diff must match the intended scope;
- deployment or migration risk must be understood.

## 15. Main Branch Governance

Protect release branches where supported.

Recommended protections:

- require status checks;
- require the full canonical CI suite;
- disable force pushes;
- disable branch deletion;
- require PR review where the project supports independent review.

If administrators retain bypass rights, treat bypass as emergency-only and document its use.

## 16. Documentation Rules

Update documentation when behavior, operations, architecture, or release policy changes.

Keep documentation aligned with actual implementation.

Do not leave roadmap items marked pending when they have been completed.

Do not change architecture/governance decisions indirectly through code. Use an explicit decision record when policy changes.

## 17. Observability

For production systems, preserve or improve:

- structured logs;
- request IDs;
- metrics;
- traces where used;
- health checks;
- alerting;
- audit events.

Do not remove operational visibility just to simplify implementation.

When debugging production, correlate user-facing symptoms with logs and metrics before changing code.

## 18. Performance Rules

Do not weaken an existing performance SLO to make a test pass.

When performance regresses:

- verify the workload is unchanged;
- profile the bottleneck;
- fix the bottleneck;
- rerun the exact workload;
- record the new measurement.

Measurements must state:
- environment;
- workload;
- concurrency;
- sample size;
- candidate SHA;
- relevant percentile or threshold.

## 19. UI/UX Work

Before redesigning a page:

- identify the user role;
- identify the user's primary decision/task;
- inspect the full workflow, not only the page;
- preserve accessibility and keyboard behavior;
- preserve error, loading, empty, offline, permission, and conflict states.

Avoid making operational software visually complex for decorative reasons.

For shared components, test every major surface that uses them.

## 20. Accessibility

Treat accessibility as a functional requirement.

Maintain:

- keyboard operation;
- visible focus;
- semantic labels/headings;
- sufficient contrast;
- reduced-motion support;
- accessible error feedback;
- screen-reader announcements where needed;
- non-drag alternatives;
- responsive reflow.

Automated accessibility checks do not substitute for human screen-reader or physical-device testing when those are required.

## 21. External Services

Before changing an external integration:

- verify the active provider and environment;
- inspect current configuration;
- distinguish staging from production;
- verify domain/DNS requirements;
- test the actual integration after change.

Do not assume a successful configuration write proves the service works.

Examples include:
- email;
- identity;
- payments;
- analytics;
- object storage;
- DNS;
- CDN;
- hosting;
- monitoring.

## 22. Error Handling

When blocked:

- finish all independent work that can still be completed;
- state exactly what is blocked;
- state what evidence is missing;
- state the minimum action required to unblock it.

Do not stop at “cannot proceed” if other useful work remains possible.

Do not invent missing access or results.

## 23. Second-Pass Review

After implementation and tests pass, review the change again.

Check for:

- unintended scope expansion;
- stale comments or docs;
- missing edge cases;
- duplicated logic;
- insecure defaults;
- hard-coded environment values;
- test-only assumptions leaking into production;
- missing observability;
- broken rollback behavior;
- backwards-compatibility issues.

Treat the second pass as part of the task, not optional polish.

## 24. Completion Report

At the end of a meaningful task, report:

- objective;
- files/systems changed;
- exact commit SHA;
- tests run and results;
- CI status;
- deployment status if relevant;
- environment tested;
- known limitations;
- remaining blockers;
- next recommended step.

Use precise statuses.

Do not say:
- “done” if required checks are still running;
- “production-ready” if production was not verified;
- “certified” if required evidence is synthetic or missing.

## 25. Stop Conditions

Stop and ask for clarification before proceeding when:

- two authoritative requirements conflict;
- the requested action would destroy or irreversibly alter data;
- a release requires an approval that has not been granted;
- the requested fix requires weakening a stated security or quality contract;
- production identity cannot be established;
- a migration cannot be made safely;
- the requested scope is materially different from what was originally authorized.

Otherwise, continue autonomously through implementation and verification.

## 26. Recommended AI Working Loop

Use this loop for every substantial task:

**Inspect → Understand → Plan → Implement → Test → Review → Verify → Report**

In more detail:

1. Inspect current state.
2. Understand the requirement and surrounding system.
3. Define scope and validation.
4. Make the smallest correct change.
5. Run focused tests.
6. Run broader regression checks.
7. Review the diff again.
8. Verify the actual deployed/runtime behavior when relevant.
9. Report evidence and remaining work.

## 27. Project-Specific Configuration

Fill this section in for each repository.

```yaml
project:
  name: "<PROJECT_NAME>"
  repository: "<OWNER/REPOSITORY>"
  default_branch: "main"
  production_branch: "main"

quality:
  required_ci_jobs:
    - "<JOB_1>"
    - "<JOB_2>"
  minimum_test_policy: "No required checks may be skipped"

release:
  exact_sha_required: true
  production_smoke_required: true
  rollback_required: true

environments:
  staging: "<STAGING_URL>"
  production: "<PRODUCTION_URL>"

security:
  secrets_in_repository: false
  admin_bypass: "emergency-only"

governance:
  architecture_decisions_path: "docs/decisions"
  runbooks_path: "docs/runbooks"
  release_evidence_path: "artifacts"
```

## 28. Final Rule

Optimize for trustworthy outcomes, not the appearance of progress.

A smaller verified result is better than a larger unverified one.
