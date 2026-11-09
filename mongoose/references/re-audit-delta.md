# Re-Audit Delta

Use for a second pass: a prior capture and its Mongoose report, plus one or more new captures taken after stated changes.

To compare a different Mac with the environment's reference report, use [Environment Baseline](environment-baseline.md) instead.

## 1. Classify And Hash

- Classify every capture as prior or new by collection timestamp, not by file name or upload order.
- Record each capture's SHA-256 before analysis. Re-check at the end and report both in the Captures table.
- Confirm every capture names the same serial number. A mismatch means a different Mac: stop and ask. If the prior report redacted the serial, confirm it from the prior capture instead.
- A preliminary report from [Preliminary Audit](preliminary-audit.md) is a valid prior. Its inventory JSON is the prior capture, and each item it marked Not observable becomes a re-test against the new logs. It is never a valid environment baseline.

## 2. Re-Test, Do Not Copy

- Treat every prior finding as a hypothesis to re-test against both captures, not a conclusion to copy.
- Re-derive wording, counts and conclusions from the evidence.

## 3. Verify Stated Changes

- Verify each stated change with evidence from both captures: before in the prior capture, after in the new capture.
- Flag a stated change that is an unfilled placeholder, or that the evidence contradicts.
- Watch for server-side changes missing from the stated list. Example: a DDM declaration whose content changed. Compare declaration identity by hash, such as a SHA-256 of the declaration payload or its server token. Never print the keys or payload values.

## 4. Compare Like With Like

- Measure each window from first boot.
- Cut the prior capture to the same duration as the new window, per source. Record the cut lines as `file:Lstart-Lend` with their original timestamps.
- Normalize counts to rates: per hour, per boot or per policy run.
- Re-measure the prior capture with the same commands and patterns used on the new capture. Note any difference from the prior report's figures and its cause (method, window or counting).

## 5. Check Comparability Before Judging

| Check | Question | If they differ |
|---|---|---|
| Window length | Same duration from first boot? | Cut the longer window; compare rates |
| Starting OS | Same installed OS at start? EraseDevice keeps the installed OS, so update paths may not be exercised | Mark update findings "Not comparable" |
| Scope or ring | Did opt-ins or group changes move the Mac between smart groups mid-window? | Split the window at the change |
| Inventory snapshot age | Were the snapshots taken at a similar age after enrollment? | Compare only time-independent values |
| Counting method | Same patterns and splitting rules? | Re-count the prior capture |

## 6. Delta Table

One row per prior finding, in prior order.

| Prior finding | Status | Prior evidence | New evidence | Confidence |
|---|---|---|---|---|
| `<B1. title>` | Fixed / Improved / Unchanged / Worse / Not observable | `<file>:L<n>` | `<file>:L<n>` | <level> |

- Status is one of Fixed, Improved, Unchanged, Worse or Not observable.
- Mark sub-items "Not comparable" when the comparability checks fail, and say which check.
- Label findings absent from the prior report **New** in the Good, Bad and Ugly sections.

## 7. Re-Test Checklist Results

- Take the checklist from the prior report's next steps, or build one from its findings.
- For each item: Pass, Fail or Not observable, with evidence from the new capture.
