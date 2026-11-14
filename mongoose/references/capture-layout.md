# Capture Layout

Detect layout from contents, not names. Captures are often incomplete.

## Client-Log Bundle

A ZIP or directory of copied `/var/log` files, made by a log-collection policy or script. Any collector's bundle qualifies, not only `mongooseCollect.zsh`. Mongoose reads it off the Mac. Members may sit in nested folders, for example `Logs/managed/<script>.log`.

- Members are often prefixed with a device ID and a collection timestamp, for example `<computer-id>-<YYYY-MM-DD-HHMMSS>-system.log`. Treat the ID as sensitive. In Jamf Pro it is usually the Computer ID.
- Treat the collection timestamp as collection time, not incident time.
- Confirm what each member is from its first and last lines. Renamed and truncated files are common.
- Collection scripts can copy a log while it is still being written and can skip missing rotated logs. See [Interpretation Rules](interpretation-rules.md).
- A collection manifest member, for example `*-mongooseCollect-manifest.txt`, may state collection time with UTC offset, time zone, boot time, macOS build, serial number, and each member's size, source modification time and SHA-256, plus logs missing or not collected. It may also name the MDM vendor detected from the enrollment profile and the MDM agent log's source: a file path, or a Unified Logging predicate. Use it as a collection-time anchor and an inventory cross-check. A member the manifest does not list, or whose SHA-256 differs from the manifest's, goes under Limitations, and no finding rests on it alone. Cite it like any member. Its time is collection time, not incident time.

## Device Identity

Reports name the Mac by serial number. Look for it in these places, and cite the source:

- MDM inventory JSON export: search key paths for `serial` (see [Inventory Commands](inventory-commands.md)), then cite the key path and snapshot time. Use the hardware or general serial; disk and certificate serials do not identify the Mac.
- Organization scripts that print it to their script logs, such as onboarding or health-check banners.
- A collection manifest member or a member-name prefix that carries it. Cross-check either against a log or inventory source.
- Sysdiagnose hardware data in `SystemProfiler/*.spx`.
- `Terminal Saved Output*.txt` transcripts that printed it.

Cross-check rules live in [Evidence Safety](evidence-safety.md). Never infer a serial from a hostname or other partial string.

## Primary Sources

- `system.log` and rotated `system.log.<n>.gz`: boot and shutdown markers, launchd, daemons, and scripts that log to syslog.
- `<mdm>.log`: the MDM agent log. Jamf Pro is the worked example: `jamf.log` records enrollment, policy execution (`Executing Policy <name>`), recurring check-in, inventory (`jamf recon`) and script activity. It records no script exit codes; take those from the script's own log lines or the Jamf Pro policy log. The MDM agent log may instead be a Unified Logging export, `*-mdm-agent.log`, whose manifest `source` is a `log show` command. It prints local time without a UTC offset; take the offset from the manifest. A member with only the header line means no entries in the window, and its Modified time is export time, not agent activity. For other MDMs, ask the operator for the agent log path or Unified Logging predicate; do not guess.
- **Organization script logs**, in one of two layouts. Both may appear in one bundle.
  - **Shared:** `<rdnn>.log`, the reverse-domain script log, for example `/var/log/com.example.it.log`. Many scripts may write to it, often in different formats. Split it into per-script blocks ([Script-Deployment Playbooks](script-deployment-playbooks.md#per-script-measurements)). This is the default when present.
  - **Per-script directory:** `<script-log-dir>/**/*.log`, one log per script, for example `/var/log/managed/<script>.log`. The Mac Admin names the directory, as a live path or as a folder in the bundle. Find its members two ways:
    - In a `mongooseCollect` bundle, read the manifest's `source` column. That collector flattens paths, so member names alone do not show the directory.
    - In any other ZIP or folder, match the path prefix, for example `Logs/managed/`.
  - When no directory is named and members look like per-script logs, ask the Mac Admin. Never assume a layout from names alone.
  - Each per-script file is one script's log. Group rotated siblings (`<script>.log.0.gz`) with their base file. The file stem suggests the script name; confirm it from a banner or log prefix in the file. A file that holds several scripts is split as `<rdnn>.log` is.

## Optional Sources

- `install.log`: macOS Installer, package and software-update activity.
- MDM inventory JSON export: server-side state at snapshot time. Record the snapshot time and its age relative to the capture. Treat every field as sensitive. On its own it supports a [Preliminary Audit](preliminary-audit.md). In a Jamf Pro Computer Record, an `attachments[].sizeBytes` equal to the bundle's byte size confirms that the log-capture upload reached the MDM.
- Apple sysdiagnose: see [Sysdiagnose Capture Layout](sysdiagnose/capture-layout.md).
- `Terminal Saved Output*.txt`: follow-up commands run on the impacted Mac, with their output. Later transcripts may refine or replace earlier hypotheses. In Jamf Pro, `jamf recon -verbose` output ends with `<computer_id>`; use it to confirm that a transcript and a bundle refer to the same record, and treat the value as sensitive.
- A prior Mongoose report: input to a re-audit. See [Re-Audit Delta](re-audit-delta.md).

## Optional Component Logs

Many fleets run community tools. None is assumed. Detect each from contents, then apply its rules in [Interpretation Rules](interpretation-rules.md).

- App Auto-Patch: `*-aap.log`, `*-aap_verbose.log`, and App Auto-Patch 4 `*-aap4.log`.
- Installomator, Setup Your Mac, DDM OS Reminder, Mac Health Check and Jamf Pro Health Check may write to their own logs or to `<rdnn>.log`. Identify them by banner or log prefix.
- Endpoint privilege management audit logs, for example `defendpoint.audit.log`. Often structured multi-line records.
- Jamf Pro Self Service+: `*-selfserviceplus.log`, exported from Unified Logging with `log show --style compact`, which prints local time with no UTC offset; take the offset from the manifest. A member with only the header line means no entries in the window, bounded by the window and log retention. Expect end-user names and paths; sanitize them.

Names and availability vary. Determine format from contents; do not rely only on file name, extension or `file` output.
