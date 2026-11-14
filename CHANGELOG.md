# CHANGELOG

## Version History

### Unreleased

- Add a fictional sample report, `examples/mongoose-sample-report.md`
- Skill: MDM health summary (`references/mdm-health/`) that rolls up finished endpoint reports for one client's MDM from a manifest: validated generic aliases, sanitized MDM and Notes text, one client per run, report paths confined to the report directory, manifest and report hashes before reading, report time from each report's named collection source, default seven-day periods, prevalence from each endpoint's newest report with a stated rule for which endpoints could observe each category, and trend statuses over endpoints sampled in both periods only; never across clients or MDMs, never writes serials, and asks no redaction question (issue #2)
- Report: the Captures table states each collection or snapshot time with its offset
- Add a fictional sample MDM health summary, `examples/mongoose-sample-mdm-health.md`
- CONTRIBUTING: minimum inputs to add another MDM
- Skill: read organization script logs from a per-script log directory the Mac Admin names (`<script-log-dir>`), as well as from `<rdnn>.log`, and state that Mongoose runs off the Mac on any collected client-log bundle, including nested folders (issue #4)
- `mongooseCollect.zsh` 0.0.2: add Parameter 8, a per-script log directory collected recursively (plain `*.log` files and their rotated siblings; symlinks and hidden directories skipped; `/` refused; 500-file cap on `*.log` and rotated files combined; never written, so a Parameter 4 log inside it is not appended to and an output directory inside it is refused), with flattened member names and manifest lines for the directory and the files discovered (issue #4). A rejected Parameter 8 no longer marks the bundle incomplete when Parameter 4 yields a log, and rotated siblings of every log are limited to `<log>.<n>`, `<log>.<n>.gz` and `<log>.<n>.bz2`

### 0.0.1 (10-Nov-2026)

- Initial release