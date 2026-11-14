# Environment Baseline

Use when the Mac Admin asks to set a Mongoose report as the environment baseline, or when an audit runs while one is set.

A baseline is the Mac Admin's reference for how managed Macs behave in their environment. Later audits of any Mac compare with it. [Re-Audit Delta](re-audit-delta.md) is different: it compares one Mac before and after stated changes. Both can apply in one run.

## Eligibility

Check the report itself, not the request. Only a full audit report qualifies:

- File name `reports/mongoose-gbu-<YYYY-MM-DD-HHMMSS>.md`, or the same name with a `-<n>` rerun suffix, and title `# Mongoose: The Good, The Bad, and The Ugly`.
- The Members table covers `system.log`, `<mdm>.log` and the script logs (`<rdnn>.log` or `<script-log-dir>`).
- The Handling line shows matching SHA-256 before and after.

Refuse a preliminary report from [Preliminary Audit](preliminary-audit.md): a `mongoose-gbu-preliminary-` file name, a `(Preliminary)` title or an inventory-JSON-only scope. One inventory snapshot shows state. It shows no policy runs, script behavior, exit codes, durations, rates or log noise, and those are what a baseline must hold. Offer the path instead: collect the client-log bundle, run the full audit with the preliminary report as the prior report, then set that report.

Ask for explicit confirmation, and record the answer, when a full report:

- Lacks a primary source. Name the gap.
- Holds Bad or Ugly findings. List them by number and title. The record marks them accepted at set time; later audits still report them.

## Set The Baseline

1. Act only on the Mac Admin's request. Never offer, set or replace a baseline unprompted.
2. During an audit, wait until the redaction prompt is answered, so the report is final.
3. Check eligibility.
4. If `reports/mongoose-baseline.md` exists, name its report and set date, then ask before replacing it.
5. Confirm `reports/` is git-ignored, as in [Report: The Good, The Bad, And The Ugly](report-gbu.md#file). If it is not, ask.
6. Hash the report, then write the record. Take every value from the report and its hash; never fill one from memory.
7. Confirm in one line: the report file and its SHA-256 prefix.

```zsh
report='reports/mongoose-gbu-<YYYY-MM-DD-HHMMSS>.md'

# Expect a match; otherwise ask before writing.
git check-ignore -q 'reports/probe.md' && print -r -- 'reports/ is git-ignored'
shasum -a 256 -- "$report"
```

Write the record to `reports/mongoose-baseline.md`:

```markdown
# Mongoose Baseline

- **Report:** `reports/mongoose-gbu-<YYYY-MM-DD-HHMMSS>.md`
- **Report SHA-256:** `<sha256>`
- **Set:** <YYYY-MM-DD>
- **Captures:** `<capture>` (`<sha256-prefix>`), from the report's Captures table
- **Comparability:** <model and architecture>; macOS <version> (<build>); <MDM agent version>; evidence window <duration> from first boot; enrollment age at collection <age>
- **Primary sources:** `system.log`, `<mdm>.log`, script logs (`<rdnn>.log` or `<script-log-dir>`). Gaps accepted: <none / list>
- **Bad and Ugly accepted at set time:** <none / B1. title; U1. title>
```

## Use The Baseline

At SKILL.md Step 1, when `reports/mongoose-baseline.md` exists:

- Re-hash the baseline report. If it is missing or its hash differs from the record, say so and ask: continue without the baseline, or set it again. Never compare with a changed report silently.
- Name the baseline in the report header: report file, set date and SHA-256 prefix.
- Treat the baseline as reference, not as evidence about this Mac. Cite it only in the delta.
- Write this audit's findings from its own evidence first. Compare at SKILL.md Step 7, so the baseline cannot steer them.
- If the baseline's captures are in `logs/` and match the record's SHA-256, re-measure them with the same commands and patterns as this audit. Otherwise compare with the report's figures and say so under Limitations.
- Expect a different serial number. If it matches the baseline's, ask whether a re-audit delta was meant. Skip this check when the baseline report redacted the serial.
- Apply the comparability checks in [Re-Audit Delta](re-audit-delta.md#5-check-comparability-before-judging), skill version included, plus model and architecture, MDM agent version, and scope or ring.
- A preliminary audit compares only areas both reports observe. Mark the rest Not observable.

## Delta Vs. Baseline

Place it after the executive summary and any re-audit sections, per [Report: The Good, The Bad, And The Ugly](report-gbu.md#order). One row per area.

| Area | Baseline | This audit | Status | Evidence |
|---|---|---|---|---|
| `<B1. title>` or `<script-name>`: runs per hour | <value> | <value> | Matches / Better / Worse / Off-baseline / Absent here / Not comparable | `<file>:L<n>` |

- Areas: every Bad and Ugly finding in either report; each script-lens row (exit codes, duration, runs per hour, noise per run); recurring warnings.
- **Off-baseline:** seen here, not in the baseline. **Absent here:** in the baseline, not seen here. Absence from a short, rotated or truncated source proves little; say which.
- Compare rates, never raw counts from windows of different length.
- Mark a row Not comparable when a comparability check fails, and name the check.

## Labels And Classes

- Tag every numbered finding **In baseline** or **Off-baseline**.
- A baseline never suppresses, downgrades or reclassifies a finding. An Ugly finding the baseline accepted stays Ugly.
- The executive summary leads with Off-baseline Bad and Ugly findings.

## Clear The Baseline

On request only. Confirm first, then delete `reports/mongoose-baseline.md`. Never delete the report it points to.
