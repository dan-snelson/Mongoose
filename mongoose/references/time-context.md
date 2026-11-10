# Time Context

Establish time context before correlating anything. Most Mongoose sources carry no year and no offset.

## Kinds Of Time

Keep these distinct in notes, citations and the report:

- **Incident time:** when the symptom or policy run happened.
- **Collection time:** when the bundle, sysdiagnose or export was made. Bundle and member prefixes usually carry it.
- **Endpoint local time:** what the Mac's clock and time zone showed at that moment.
- **UTC:** `Z` timestamps and epoch values.
- **File modification time:** when a copy was written. Often the collection time, not the event time.
- **Inventory snapshot time:** when the MDM recorded an inventory value.

## Establish Context

- Host time zone, from offset-bearing sources (`install.log`, sysdiagnose, inventory) rather than assumption.
- Explicit UTC offsets and `Z` timestamps.
- Daylight-saving boundaries inside the window.
- Sources that lack a year or an offset.
- Clock changes: a network time sync after first connection can step the clock forward or back. Look for gaps and backward steps.
- Year rollover: infer the year from collection time, and watch a December-to-January window.

## Source Formats

| Source | Typical timestamp | Year | Offset | Normalization |
|---|---|---|---|---|
| `system.log` | `Mmm dd HH:MM:SS` (BSD syslog) | No | No | Infer year from collection time; anchor with `BOOT_TIME` / `SHUTDOWN_TIME` epochs |
| `<mdm>.log` (Jamf Pro `jamf.log`) | `Ddd Mmm dd HH:MM:SS <hostname> jamf[<pid>]:` | No | No | As system.log; cross-anchor on shared events |
| `<rdnn>.log` | Set by each script; often several formats in one file | Varies | Varies | Count formats per script; anchor each to system.log or `<mdm>.log` events |
| `install.log` | `YYYY-MM-DD HH:MM:SS` plus a short offset such as `-07` | Yes | Yes | Use the stated offset; BSD-style lines without an offset during erase or early boot are UTC |
| Unified log (`log show`) | Rendered in the zone passed to `--timezone` | Yes | Yes | Always pass `--timezone` and state the zone |
| Sysdiagnose file name | Capture start with an explicit UTC offset | Yes | Yes | Confirm against `sysdiagnose.log` |
| MDM inventory JSON | ISO 8601 or epoch, per field | Yes | Usually UTC | Record the snapshot time the export states |
| `Terminal Saved Output*.txt` | Only what the commands printed | Varies | Varies | Treat as a later capture, not incident evidence |

## Anchoring Techniques

- **Boot and shutdown epochs.** system.log lines carrying `BOOT_TIME` and `SHUTDOWN_TIME` include an epoch value. Convert it to UTC and compare it with the local stamp on the same line. The difference is the effective offset at that moment.
- **Shared events.** An event that appears in more than one source fixes the offset of the offset-less one. Examples: a policy run in `<mdm>.log` and its script's lines in `<rdnn>.log`; a package install in `<mdm>.log` and in `install.log`, which carries an offset.
- **Setup Assistant.** Setup Assistant starts on Pacific time by default. The offset can change mid-log once the time zone is set by the user, by location services or by a profile. Split the timeline into offset segments and re-anchor each one.
- **Offset switch.** The last `install.log` line with the old offset and the first with the new one bound the switch to seconds. Offset-less sources show a false jump of the offset difference there: not a gap, a sleep or a slow run. Correct any duration that spans it. A script that logs its own measured wait across the switch confirms the anchor. Values stored as offset-less wall-clock time before the switch, such as extension-attribute dates, keep the old offset.
- **Early install.log.** BSD-style `install.log` stamps without an offset during erase or early boot are UTC.

```zsh
# Convert a BOOT_TIME or SHUTDOWN_TIME epoch to UTC and to the endpoint's zone.
epoch='<epoch-seconds>'
date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ'
TZ='<Area/City>' date -r "$epoch" '+%Y-%m-%d %H:%M:%S %z'
```

## Normalizing The Timeline

- Pick one offset for the material timeline and state it in the report.
- Keep each row's original timestamp and `file:Lnn` next to the normalized time.
- Mark a normalized time as inferred when it depends on an anchor, and name the anchor.
- Measure every window from first boot (the first `BOOT_TIME` in the evidence), so windows from different captures compare.
