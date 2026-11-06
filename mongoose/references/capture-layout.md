# Capture Layout

Detect layout from contents, not names. Captures are often incomplete.

## Client-Log Bundle

A ZIP or directory of copied `/var/log` files, made by a log-collection policy or script.

- Members are often prefixed with a device ID and a collection timestamp, for example `<computer-id>-<YYYY-MM-DD-HHMMSS>-system.log`. Treat the ID as sensitive. In Jamf Pro it is usually the Computer ID.
- Treat the collection timestamp as collection time, not incident time.
- Confirm what each member is from its first and last lines. Renamed and truncated files are common.
- Collection scripts can copy a log while it is still being written and can skip missing rotated logs. See [Interpretation Rules](interpretation-rules.md).

## Primary Sources

- `system.log` and rotated `system.log.<n>.gz`: boot and shutdown markers, launchd, daemons, and scripts that log to syslog.
- `<mdm>.log`: the MDM agent log. Jamf Pro is the worked example: `jamf.log` records enrollment, policy execution (`Executing Policy <name>`), recurring check-in, inventory (`jamf recon`) and script activity. For other MDMs, ask the operator for the agent log path; do not guess.
- `<rdnn>.log`: the organization's reverse-domain script log, for example `/var/log/com.example.it.log`. Many scripts may write to it, often in different formats.

## Optional Sources

- `install.log`: macOS Installer, package and software-update activity.
- MDM inventory JSON export: server-side state at snapshot time. Record the snapshot time and its age relative to the capture. Treat every field as sensitive.
- Apple sysdiagnose: see [Sysdiagnose Capture Layout](sysdiagnose/capture-layout.md).
- `Terminal Saved Output*.txt`: follow-up commands run on the impacted Mac, with their output. Later transcripts may refine or replace earlier hypotheses. In Jamf Pro, `jamf recon -verbose` output ends with `<computer_id>`; use it to confirm that a transcript and a bundle refer to the same record, and treat the value as sensitive.
- A prior Mongoose report: input to a re-audit. See [Re-Audit Delta](re-audit-delta.md).

## Optional Component Logs

Many fleets run community tools. None is assumed. Detect each from contents, then apply its rules in [Interpretation Rules](interpretation-rules.md).

- App Auto-Patch: `*-aap.log`, `*-aap_verbose.log`, and App Auto-Patch 4 `*-aap4.log`.
- Installomator, Setup Your Mac, DDM OS Reminder, Mac Health Check and Jamf Pro Health Check may write to their own logs or to `<rdnn>.log`. Identify them by banner or log prefix.
- Endpoint privilege management audit logs, for example `defendpoint.audit.log`. Often structured multi-line records.

Names and availability vary. Determine format from contents; do not rely only on file name, extension or `file` output.
