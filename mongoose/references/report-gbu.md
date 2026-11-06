# Report: The Good, The Bad, And The Ugly

## File

- Write to `reports/mongoose-gbu-<YYYY-MM-DD-HHMMSS>.md` in the working directory.
- Name it from the capture's collection timestamp, never from today's date. On a re-audit, use the newest capture. State the source of the timestamp in the header.
- Create `reports/` if missing. Before writing, confirm it is git-ignored, for example with `git check-ignore -q reports/probe.md`. If it is not, ask.
- Sanitize per [Evidence Safety](evidence-safety.md). The serial number stays, as the report's identity; it never goes in the file name, so redaction needs no rename.

## Labels

- **Obs:** observation. What the evidence shows, with a citation.
- **Inf:** inference, with a confidence level (high, medium or low).
- **Conclusion:** only when independent signals agree.
- **New:** re-audit only. A finding that is not in the prior report.

## Classes

- **The Good:** working as designed, with evidence.
- **The Bad:** bounded defects.
- **The Ugly:** user impact, security exposure or data exposure.

## Order

1. **Header.** Scope. Mac: serial number with its source citation, plus model and OS when the evidence states them; if no source states a serial, say so here and under Limitations. Evidence window: start and end with their original offsets, plus duration from first boot. Prepared date and sanitization statement. Label legend.
2. **Evidence and method.**
   - Captures table: name, class (baseline or new), collection or snapshot time, integrity check, SHA-256 prefix.
   - Members table: member, lines, notes (truncated tail, rotated, missing).
   - Handling: hashes before and after, nothing executed, streamed not extracted. Name any extraction and where it went.
   - Skills applied: `mongoose` and the references used.
3. **Time context.**
   - Table: source, timestamp format, normalization, anchors.
   - Material timeline, normalized to one offset. Each row cites the original source as `file:Lnn` with the original timestamp.
4. **1. Executive summary.** Three to six sentences: overall health, primary findings, confidence, material limitations.
5. **Re-audit only.** "Delta vs. prior audit", then "Re-test checklist results". Method: [Re-Audit Delta](re-audit-delta.md).
6. **2. The Good, 3. The Bad, 4. The Ugly.** Numbered findings. Each has Obs, Inf and Conclusion bullets with citations, plus alternatives still open where relevant.
7. **5. Cross-cutting observations.** Patterns across findings, including the script-deployment lens. With a sysdiagnose, cover crashes and hangs, performance, power and thermal, network, storage, and security and privacy; mark unavailable categories and why.
8. **6. Limitations and missing evidence.** Missing artifacts, collection failures, truncation, short log coverage, snapshot age, uncertain time context and untested assumptions.
9. **7. Recommended next steps.**
   - P1, P2 and P3 items. Frame every configuration or endpoint change as a recommendation for the owning team.
   - Then one round of read-only, paste-ready Zsh follow-up commands, in groups.

## Script-Deployment Lens

For each organization script seen in `<rdnn>.log`, and its policy in `<mdm>.log`, assess:

- versioned log prefix
- timestamp offset
- exit codes and duration
- concurrency and interleaving
- redundant runs and trigger use
- secrets passed as policy parameters
- PII written to uploaded logs
- contribution to endpoint-security and `install.log` noise

Measurement methods: [Script-Deployment Playbooks](script-deployment-playbooks.md). Report one row per script; place each defect in Bad or Ugly as a numbered finding.

| Script | Version prefix | Offset | Exit / duration | Concurrency | Redundant runs / trigger | Secrets in parameters | PII in log | ES / install.log noise |
|---|---|---|---|---|---|---|---|---|
| `<script-name>` | `<yes/no, share>` | `<yes/no>` | `<codes; median, max>` | `<overlaps>` | `<runs per hour; trigger>` | `<none / exposed in where>` | `<none / types>` | `<lines per run>` |

## Follow-Up Command Groups

Each group states its purpose, whether `sudo` is needed, what output to return and how to stop it.

```zsh
# Group 1: confirm the effective time zone and last boot.
# sudo: no. Return: all output. Stop: finishes on its own.
readlink /etc/localtime
sysctl -n kern.boottime

# Group 2: MDM client activity in one bounded window.
# sudo: no. Return: all output. Stop: Control-C.
/usr/bin/log show --style compact \
  --start 'YYYY-MM-DD HH:MM:SS' \
  --end 'YYYY-MM-DD HH:MM:SS' \
  --predicate 'process == "mdmclient"'
```

## Redaction Prompt

Run after the report is written and the findings are complete.

1. Ask one question: keep or redact the serial number.
2. **Keep:** leave the report as written. Say in the closing message that the report identifies the Mac by serial number.
3. **Redact:** edit the same file in place.
   - Replace every exact occurrence of the serial with `<serial>`, including any fragment the report quotes.
   - Change the Prepared line to: "Sanitized: identifiers replaced with placeholders, including the serial number."
   - Verify that no copy remains:

```zsh
serial='<serial>'
report='reports/mongoose-gbu-<YYYY-MM-DD-HHMMSS>.md'

# Expect 0.
rg -c -F -- "$serial" "$report" || print -r -- '0'
```

## Skeleton

```markdown
# Mongoose: The Good, The Bad, and The Ugly

- **Scope:** <what was audited and why>
- **Mac:** Serial number `<serial>` (`<file>:L<n>` or `<key path>`); <model>; macOS <version> (<build>)
- **Evidence window:** <start with original offset> to <end with original offset>; <duration> from first boot
- **Prepared:** <YYYY-MM-DD>. Sanitized: identifiers other than the serial number replaced with placeholders.
- **Labels:** Obs = observation. Inf = inference (confidence). Conclusion = independent signals agree. **New** = not in prior audit.

## Evidence and method

| Capture | Class | Collection / snapshot time | Integrity | SHA-256 |
|---|---|---|---|---|
| `<capture>` | baseline / new | <time with offset> | <unzip -t OK> | `<sha256-prefix>` |

| Member | Lines | Notes |
|---|---|---|
| `<prefix>-system.log` | <n> | <truncated tail? rotated?> |

- **Handling:** SHA-256 before and after match; nothing executed; streamed, not extracted.
- **Skills applied:** mongoose (<references used>)

## Time context

| Source | Timestamp format | Normalization | Anchors |
|---|---|---|---|
| system.log | Mmm dd HH:MM:SS | <offset> | BOOT_TIME epoch at `<file>:L<n>` |

| Normalized time | Event | Source (original timestamp) |
|---|---|---|
| <time> | <event> | `<file>:L<n>` (<original>) |

## 1. Executive summary

<three to six sentences>

## Delta vs. prior audit (re-audit only)

## Re-test checklist results (re-audit only)

## 2. The Good

### G1. <title>
- **Obs:** <evidence> (`<file>:L<n>`, <original timestamp>)
- **Inf:** <inference> (confidence: <level>)
- **Conclusion:** <only when independent signals agree>

## 3. The Bad

### B1. <title>

## 4. The Ugly

### U1. <title>

## 5. Cross-cutting observations

## 6. Limitations and missing evidence

## 7. Recommended next steps

- **P1:** <recommendation for owning team>
- **P2:**
- **P3:**

<grouped read-only Zsh follow-up commands>
```
