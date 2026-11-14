# Interpretation Rules

Patterns that change conclusions. Apply the core rules on any fleet. Apply an optional rule only after detecting its component in the evidence.

## Core

### Installer Success Is Not Postinstall Success

- A package can log `Installed` after its postinstall download failed, for example an SSL timeout (curl error 28).
- Before calling a package Good, find the postinstall's own outcome in `install.log`, the script logs (`<rdnn>.log` or per-script files) or the component's log, and check that what it fetches exists afterward.
- Report "installed, postinstall failed" as Bad, not Good.

### `MDM conflicts with DDM, ignoring OS updates`

- mdmclient logs this from its available-updates lookup while a DDM declaration is active.
- Correlate each occurrence with whatever queried available updates at that moment, for example a health-check script.
- Do this before inferring that legacy MDM software-update settings are in play.

### Past-Due DDM Declarations

- A declaration can reach a new enrollment already past its `EnforcedInstallDate`. That forces a restart within the first hour. A deadline later the same day still forces a day-one install and restart; report it as user impact, measured from first login.
- Compare `EnforcedInstallDate` with the enrollment time.
- Also check fallback dates hard-coded in reminder scripts. A stale fallback can disagree with the declaration. `EnforcedInstallDate` is device-local time with no zone; a fallback written with `Z` is UTC and shifts the deadline by the UTC offset.

### Time Zones And Anchors

- Setup Assistant starts on Pacific time by default, so the offset changes mid-log once the time zone is set.
- In `install.log`, BSD-style stamps without an offset during erase or early boot are UTC.
- Anchor offset-less sources (system.log, `<mdm>.log`, script logs) with system.log `BOOT_TIME` and `SHUTDOWN_TIME` epoch values and with events that appear in more than one source. Method: [Time Context](time-context.md).

### Collection Artifacts

- Log-collection scripts can copy a log while it is still being written. A truncated tail is a collection artifact, not a crash or hang.
- They can skip missing rotated logs. A gap before the current file is a collection limit, not quiet behavior.

### Snapshot Age

- Time-dependent inventory values are not comparable between snapshots of different age: health state, remediation state, SSO registration, Remote Desktop state.
- Record each snapshot's time and its age at collection before comparing values.
- Inventory values and extension attributes date from the last inventory report (Jamf Pro: `reportDate`), not from the export time. Check-in time can be newer.

### Recurring Warnings

- A warning that recurs in every window is not causal without temporal and behavioral correlation with the symptom.

## Optional Components

Most fleets do not use these. Detect first; otherwise skip the section.

### Negative-Trust Health Checks

- **Detect:** something writes "unhealthy" when its LaunchDaemon loads.
- "Unhealthy" at load is by design. Do not report the value itself as a fault.
- Check that the scheduled decay and the inventory run that restores the state actually happen. A missing restore is the finding.
- Example: Jamf Pro Health Check, https://snelson.us/2024/01/negative-trust-jamf-pro-health-check

### Endpoint Privilege Management Audit Logs

- **Detect:** an EPM audit log, for example `defendpoint.audit.log`.
- It may audit only user-context executions, so root-helper activity is absent. Absence there does not show the helper did not run.
- Right after the client installs, before its policy arrives, it can log that it is disabled because the policy is invalid. Report that only if it persists past the first allow or deny decision.
- Count records by their header lines, then break them down by type. Decision verbs are not the only record type; authorization-request displays and status records also appear, and counting one verb undercounts.
- It may record one CommandLine for many rapid children of the same parent (App-Auto-Patch/AAP4-Swift#355). Do not count CommandLine values as distinct executions.
- On recent macOS, Apple binaries can chain to a "macOS Software Signing" leaf certificate. Publisher rules that exact-match "Software Signing" miss them.

### App Auto-Patch 4 With A Pushed Custom Installomator

- **Detect:** `*-aap4.log`, plus an Installomator package deployed by the MDM.
- `InstallomatorUpdateDisable=true` is required, so App Auto-Patch does not update the pushed Installomator.
- Install the Installomator package before App Auto-Patch.
- A post-install relaunch ("kick-start") can start a duplicate discovery and an extra root-helper restart. Account for it before calling those runs redundant.
