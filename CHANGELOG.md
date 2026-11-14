# CHANGELOG

## Version History

### Unreleased

- Add a fictional sample report, `examples/mongoose-sample-report.md`
- Skill: read organization script logs from a per-script log directory the Mac Admin names (`<script-log-dir>`), as well as from `<rdnn>.log`, and state that Mongoose runs off the Mac on any collected client-log bundle, including nested folders (issue #4)
- `mongooseCollect.zsh` 0.0.2: add Parameter 8, a per-script log directory collected recursively (plain `*.log` files and their rotated siblings; symlinks and hidden directories skipped; `/` refused; 500-file cap), with flattened member names and manifest lines for the directory and the files discovered (issue #4)

### 0.0.1 (10-Nov-2026)

- Initial release