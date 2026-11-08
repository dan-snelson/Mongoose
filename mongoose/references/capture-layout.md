# Capture Layout

Detect layout from contents, not names. Captures are often incomplete.

## Client-Log Bundle

A ZIP or directory of copied `/var/log` files, made by a log-collection policy or script.

- Members are often prefixed with a device ID and a collection timestamp, for example `<computer-id>-<YYYY-MM-DD-HHMMSS>-system.log`. Treat the ID as sensitive. In Jamf Pro it is usually the Computer ID.
- Treat the collection timestamp as collection time, not incident time.
- Confirm what each member is from its first and last lines. Renamed and truncated files are common.
- Collection scripts can copy a log while it is still being written and can skip missing rotated logs. See [Interpretation Rules](interpretation-rules.md).
- A collection manifest member, for example `*-mongooseCollect-manifest.txt`, may state collection time with UTC offset, time zone, boot time, macOS build, serial number, and each member's size, source modification time and SHA-256, plus logs missing or not collected. Use it as a collection-time anchor and an inventory cross-check. Cite it like any member. Its time is collection time, not incident time.

## Device Identity

Reports name the Mac by serial number. Look for it in these places, and cite the source:

- MDM inventory JSON export: search key paths for `serial` (see [Inventory Commands](inventory-commands.md)), then cite the key path and snapshot time. Use the hardware or general serial; disk and certificate serials do not identify the Mac.
- Organization scripts that print it to `<rdnn>.log`, such as onboarding or health-check banners.
- A collection manifest member or a member-name prefix that carries it. Cross-check either against a log or inventory source.
- Sysdiagnose hardware data in `SystemProfiler/*.spx`.
- `Terminal Saved Output*.txt` transcripts that printed it.

Cross-check rules live in [Evidence Safety](evidence-safety.md). Never infer a serial from a hostname or other partial string.

## Primary Sources

- `system.log` and rotated `system.log.<n>.gz`: boot and shutdown markers, launchd, daemons, and scripts that log to syslog.
- `<mdm>.log`: the MDM agent log. Jamf Pro is the worked example: `jamf.log` records enrollment, policy execution (`Executing Policy <name>`), recurring check-in, inventory (`jamf recon`) and script activity. For other MDMs, ask the operator for the agent log path; do not guess.
- `<rdnn>.log`: the organization's reverse-domain script log, for example `/var/log/com.example.it.log`. Many scripts may write to it, often in different formats.

## Optional Sources

- `install.log`: macOS Installer, package and software-update activity.
- MDM inventory JSON export: server-side state at snapshot time. Record the snapshot time and its age relative to the capture. Treat every field as sensitive. On its own it supports a [Preliminary Audit](preliminary-audit.md).
- Apple sysdiagnose: see [Sysdiagnose Capture Layout](sysdiagnose/capture-layout.md).
- `Terminal Saved Output*.txt`: follow-up commands run on the impacted Mac, with their output. Later transcripts may refine or replace earlier hypotheses. In Jamf Pro, `jamf recon -verbose` output ends with `<computer_id>`; use it to confirm that a transcript and a bundle refer to the same record, and treat the value as sensitive.
- A prior Mongoose report: input to a re-audit. See [Re-Audit Delta](re-audit-delta.md).

## Optional Component Logs

Many fleets run community tools. None is assumed. Detect each from contents, then apply its rules in [Interpretation Rules](interpretation-rules.md).

- App Auto-Patch: `*-aap.log`, `*-aap_verbose.log`, and App Auto-Patch 4 `*-aap4.log`.
- Installomator, Setup Your Mac, DDM OS Reminder, Mac Health Check and Jamf Pro Health Check may write to their own logs or to `<rdnn>.log`. Identify them by banner or log prefix.
- Endpoint privilege management audit logs, for example `defendpoint.audit.log`. Often structured multi-line records.
- Jamf Pro Self Service: `*-selfservice.log` and `*-selfservice_debug.log`, copied from the console user's home. Expect end-user names and paths; sanitize them.

Names and availability vary. Determine format from contents; do not rely only on file name, extension or `file` output.
