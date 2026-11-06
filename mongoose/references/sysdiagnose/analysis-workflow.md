# Sysdiagnose Analysis Workflow

Prioritize symptom-specific evidence while still checking broad system health. Adjust the order only when the reported symptom makes another source more probative.

## 1. System Snapshot And Capture Context

- Read `sw_vers.txt`, `uptime.txt`, relevant `SystemProfiler/*.spx` and `sysdiagnose.log`.
- Record model, architecture, OS version and build, capture start and end, time zone, uptime, boot context, capture mode and source, selected process, and presence of serial or inventory identifiers when available.
- Sanitize identifier values unless the case requires them.
- Review collection task counts, timeouts, errors and summaries.
- Do not confuse sysdiagnose CPU and I/O activity or collection failures with preexisting host faults.

## 2. Unified Logs

- Query `system_logs.logarchive` with `log show --archive`, a bounded incident window and focused predicates.
- Begin with the symptom process, subsystem or category. For MDM audits, start with `mdmclient`, `softwareupdated`, `installd` and the organization's script processes.
- Widen to errors, faults, assertions, signposts, launch and termination, memory pressure, thermal, power, network, storage or security events only as needed.
- Quantify repeated events with a count and window. Deduplicate repeated rendering of the same event before claiming frequency.
- Determine available coverage before using negative evidence. Sysdiagnose logarchives often cover shorter recent windows than a dedicated `log collect`.
- Check logging density per boot. Info and Debug lines may be complete only for the boot that took the sysdiagnose; earlier boots may log almost nothing.
- Pass `--timezone` so archive timestamps render in endpoint local time, and state the zone in citations.

## 3. Crashes Hangs And Stack Evidence

- Inventory `crashes_and_spins/`, `DiagnosticReports/`, `*.ips`, panic reports, `spindump.txt`, `sample-*.txt`, `microstackshots` and stackshots.
- For each relevant report, record incident timestamp, process and path, version, architecture, exception or termination reason, responsible thread, signature or backtrace pattern, parent process and recurrence count when available.
- Distinguish crash, watchdog termination, jetsam or resource kill, user quit, clean exit, hang or spin, and kernel panic.
- Correlate reports with unified logs and process snapshots. One stack sample is point-in-time evidence, not proof of sustained behavior.

## 4. Performance And Resource Pressure

- Examine `top.txt`, `ps*.txt`, `taskinfo.txt`, `footprint.txt`, `vm_stat.txt`, `zprint.txt`, samples, spindump and systemstats data.
- Quantify CPU, resident memory, virtual memory, compressed memory, swap, pageouts, process and thread state, wakeups and resource-pressure events when available.
- Separate sustained evidence from capture-time snapshots. Sysdiagnose collection consumes CPU, memory and disk I/O; attribute activity only with pre-capture or independent corroboration.
- Flag high-severity pressure first. Label isolated high CPU, large virtual size or one unusual wait state as provisional until correlated.

## 5. Power Battery And Thermal

- Review `powermetrics.txt`, `thermal.txt`, `pmset_everything.txt`, `smcDiagnose.txt`, `SystemProfiler/SPPowerDataType.spx`, battery health data, powerlogs and unified-log power and thermal events.
- Record battery condition, cycle count, capacity metrics, power source, sleep and wake assertions, thermal pressure, throttling and high-energy processes when present.
- Correlate overnight drain or wake reports with sleep and wake intervals and assertions. Do not infer battery failure from charge percentage alone.

## 6. Network Wi-Fi And Bluetooth

- Review `network-info/`, `WiFi/`, `SystemConfiguration/`, interface state, routes, DNS, proxy and VPN state, socket summaries and relevant SystemProfiler output.
- Correlate association and authentication failures, DHCP, DNS, reachability, route changes, packet-loss indicators, interface flaps, VPN and content filters, and Bluetooth events with the incident window.
- Avoid treating private IPs, dormant interfaces, listening services or cached networks as suspicious without behavioral evidence.
- When a content filter, DNS proxy or VPN may be in the path, compare configurations in one table with the same signature rows. A transition within one boot with nothing else changed is strong evidence. See [Network Filters And OHTTP](network-filter-ohttp.md).

## 7. Storage And I/O

- Review `disks.txt`, `diskutil_*.txt`, `apfs_stats.txt`, `mount.txt`, fsck output, storage SystemProfiler files, I/O samples and unified-log storage events.
- Record free space, APFS and container state, mount errors, I/O stalls, filesystem repairs, snapshot pressure and device errors.
- Distinguish low free space, ordinary APFS snapshots and transient I/O from confirmed filesystem or hardware failure.

## 8. Kernel Extensions And System Configuration

- Review `kextstat.txt`, `kmutil-diagnose.txt`, `systemextensionsctl_diagnose.txt`, `SystemProfiler/`, `sysctl.txt` and `ioreg/`.
- Identify non-Apple kernel and system extensions, activation failures, architecture or signing mismatches, driver faults, configuration profiles and hardware enumeration anomalies.
- Treat the presence of a third-party extension as context until timing and behavior support causality.

## 9. Security Privacy And Persistence

- Review `TCC*.db` or other TCC material when present, `launchctl-*.txt`, login items, system extensions, configuration profiles, security summaries, code-signing evidence and suspicious process paths.
- Do not label launchd jobs, management agents, security tools, unsigned data or unusual names as malicious without multiple supporting signals.
- Report sensitive-data exposure inherent in the capture: usernames, serial and inventory IDs, hostnames, IP and MAC addresses, SSIDs, internal URLs, filesystem paths, app and process activity, preferences, security configuration and possible user content.
- Examine only data relevant to the case. Never enumerate, quote or disclose sensitive values merely because the capture contains them.

## 10. Other Artifacts

- Review `Accessibility/`, `logs/`, `Preferences/`, `FileProvider/`, app-specific folders and collection summaries when the symptom or another finding points there.
- Treat unfamiliar folders as version- or subsystem-specific evidence. Identify format and provenance before interpretation.
