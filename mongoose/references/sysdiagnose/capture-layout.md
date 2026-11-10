# Sysdiagnose Capture Layout

Use for Apple sysdiagnose archives or extracted folders from managed Macs.

- Compressed captures normally use `logs/sysdiagnose_<YYYY.MM.DD>_<HH-MM-SS><UTC-offset>_<suffix>_macOS_<model-or-platform>_<build>.tar.gz`; fields vary by macOS release. Do not assign meaning to undocumented suffixes.
- Input may instead be an already-extracted `sysdiagnose_*` folder.
- Filename time usually identifies capture start and includes an explicit UTC offset. Confirm against `sysdiagnose.log`, `sw_vers.txt`, unified-log timestamps and other metadata.
- Content varies by OS version, capture mode, permissions, selected process, hardware and collection success. A missing expected artifact is a limitation, not proof of healthy behavior.
- Assess completeness from archive integrity, actual inventory, `sysdiagnose.log`, `errors/` and `summaries/`. A failed collection task alone does not indicate host failure.
- Treat anything extracted as derived evidence. Keep the archive unchanged and cite paths relative to the sysdiagnose root.

Common artifacts:

- `system_logs.logarchive/`: unified logging archive.
- `crashes_and_spins/`, `DiagnosticReports/` and `*.ips`: crash, hang, spin and panic material when collected.
- `spindump.txt`, `sample-*.txt`, `microstackshots`, `stackshot.kcdata`: execution samples and stack data.
- `ps.txt`, `ps_thread.txt`, `top.txt`, `taskinfo.txt`, `footprint.txt`, `vm_stat.txt`, `zprint.txt`: process and resource snapshots.
- `powermetrics.txt`, `thermal.txt`, `pmset_everything.txt`, `smcDiagnose.txt`, `SystemProfiler/SPPowerDataType.spx`, and battery and power logs.
- `network-info/`, `WiFi/`, `SystemConfiguration/`, and network-related SystemProfiler output.
- `disks.txt`, `diskutil_*.txt`, `apfs_stats.txt`, `mount.txt`, and storage-related SystemProfiler output.
- `kextstat.txt`, `kmutil-diagnose.txt`, `systemextensionsctl_diagnose.txt`, `SystemProfiler/` and `ioreg/`.
- `launchctl-*.txt`, login-item data, security summaries, preferences, configuration profiles and TCC material when present.
- `sysdiagnose.log`, `errors/` and `summaries/`: collection status and task diagnostics.

Names and available sources change with collection tooling and OS release. Determine format from contents; do not rely only on filename, extension or `file` classification.
