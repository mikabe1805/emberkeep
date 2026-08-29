# Room of Days execution mode

This is the build-phase contract between an approved direction and a finished
product surface. It does not replace `DESIGN-BIBLE.md` or
`VISUAL-WORKFLOW.md`; it prevents implementation from advancing before their
most important claims have current evidence.

## When it is required

Create an execution record for:

- a new or newly approved direction;
- a cross-screen or shared-primitive visual change;
- a distinctive interaction, material, motion, or sensory behavior;
- work described as polished, complete, premium, or release-ready.

A narrow correction inside an established direction may use
`fidelity_correction` or `focused_polish`. It may skip the early owner
checkpoint only when `inherits_from` points to a tracked full-checkpoint brief
whose first slice was accepted. The gate requires the active sources and edge
contract to remain identical and a concrete explanation of why the correction
cannot change direction. Trivial mechanical edits with a decisive existing
test do not need an execution record.

## The record

Copy `design/execution-mode/template/` to
`design/execution-mode/active/<task>/`, then replace every placeholder.

- `brief.json` locks the active source, user job, three kinds of edge, generic
  fallbacks to reject, the first real slice, ripple map, and decisive check.
- `evidence.json` ties inspections to the exact direction-brief digest and
  implementation revision, records independent critique and deviations, and
  keeps the three completion verdicts separate.

An active source must be durable inside this repository and carry its current
SHA-256 digest in `content_sha256`. A changed source invalidates later evidence
until it is deliberately re-approved and relocked. A chat summary or an image
remembered from another task is not enough. Record corrected or rejected
sources under `superseded_sources`; any unresolved `source_conflicts` blocks
implementation. Handoff additionally requires every active source to be
tracked so a local-only image cannot silently disappear.

Every passing check needs a durable artifact with its own `content_sha256`, a
generation time, represented state, input source, inspector, and concrete
observation. The artifact digest prevents a reused filename from certifying
new content. Edge and state checks must be slice-phase or later and use
production-equivalent input; ripple checks must be expansion-phase or later.
Reference-only artifacts cannot satisfy implementation checks.

Use the built-in digest commands instead of transcribing hashes by hand:

```powershell
python tool/execution_gate.py digest <artifact-or-source-file>
python tool/execution_gate.py brief-digest design/execution-mode/active/<task>
```

## Phase progression

### 1. Direction lock

```powershell
python tool/execution_gate.py check design/execution-mode/active/<task> --phase direction
```

The brief must describe observable product, interaction, and visual decisions.
Put the `brief-digest` result in `evidence.brief_sha256`. Do not implement from
adjectives alone. If the direction contract changes later, refresh that digest
and repeat the owner checkpoint; older approval no longer applies.

### 2. First real slice

Build one end-to-end representative journey with production-equivalent state:
entry, user action, visible acknowledgement, result, and the relevant state or
persistence boundary. Do not build the surrounding system yet.

After the last slice change, record the scoped source revision:

```powershell
python tool/execution_gate.py revision design/execution-mode/active/<task>
```

Then create and inspect the fresh source/build comparison and interaction
evidence. An independent reviewer who did not author the slice must tie their
findings to those artifacts. For `new_direction` and
`approved_direction_execution`, show this one slice to the owner and record the
explicit decision before expansion. `owner_checkpoint` must name the current
revision, reviewed check IDs and artifacts, and a decision time after those
artifacts were generated; an approval from an older slice cannot carry over.
Both the independent critique and owner checkpoint must review the product,
interaction, and visual edge proofs—not unrelated slice artifacts.

```powershell
python tool/execution_gate.py check design/execution-mode/active/<task> --phase slice
```

If the owner rejects it, the gate stays blocked. Diagnose the misread and reset
the source when necessary; do not polish the rejected branch incrementally.

### 3. Expansion

Expand only after the slice gate passes. Every ripple row—pushed routes,
shared primitives, transient states, long/empty/completed content, narrow and
large-text layouts, motion variants, or other affected boundaries—needs
passing evidence, a checked `not_affected` conclusion, or an explicit deferred
gate.

```powershell
python tool/execution_gate.py check design/execution-mode/active/<task> --phase expansion
```

A source deviation with a visible consequence cannot remain pending. If it
changes the approved edge, it requires owner approval rather than a silent
substitution.

### 4. Handoff

After the final implementation change, refresh the revision token and regenerate
the final evidence. Evidence from an earlier working tree cannot certify the
current one.

Handoff also requires an automated `final:code-complete` check backed by a
current durable test report and a rendered `final:comparison` check against the
current build. Verdict text by itself is not evidence.

```powershell
python tool/execution_gate.py check design/execution-mode/active/<task> --phase handoff
```

Report three verdicts exactly:

- `code_complete` — applicable deterministic checks passed;
- `visual_evidence_ready` — current comparable renders and interactions were
  directly inspected;
- `owner_device_accepted` — explicit owner acceptance and applicable physical
  device checks passed.

A passing third verdict also needs `owner_device_acceptance`: a final owner
receipt bound to the current revision and, when a physical-device check is
applicable, separate owner and device check IDs backed by real-device
artifacts. Removing a remaining gate or changing the verdict text cannot
manufacture acceptance.

The first two never imply the third. A pending owner, phone, haptic, audio,
sensor, performance, account, or release check stays in `remaining_gates` with
the exact next action.

## What the gate proves

The tool proves that the source is explicit, the edge has observable tests,
the first slice was not skipped, evidence belongs to the current source
revision, and remaining gates are honestly represented. It does not decide
whether a screen is beautiful. `VISUAL-WORKFLOW.md`, direct artifact review,
real interaction use, and owner/device judgment remain the sources of that
evidence.
