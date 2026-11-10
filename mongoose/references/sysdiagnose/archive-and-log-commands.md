# Sysdiagnose Archive And Log Commands

Use read-only tools first. Quote archive paths because names may contain spaces.

## Archive Validation And Streaming

```zsh
archive='logs/sysdiagnose_<timestamp>_<suffix>.tar.gz'

# Hash before analysis; repeat at the end and compare.
shasum -a 256 "$archive"

# Confirm type and compressed-stream integrity.
stat -f '%z bytes\t%Sm\t%N' -t '%Y-%m-%d %H:%M:%S %z' "$archive"
file "$archive"
gzip -t "$archive"

# Inventory. Stop if output shows absolute or parent-traversal paths.
tar -tzf "$archive" | sed -n '1,200p'
tar -tzf "$archive" | awk '/^\// || /(^|\/)\.\.($|\/)/ { print "UNSAFE\t" $0 }'

# Review archive links as evidence; never follow them.
tar -tvzf "$archive" | awk '$1 ~ /^[lh]/ { print }'

# Stream text members to stdout; nothing is written to disk.
tar -xOzf "$archive" '<sysdiagnose-root>/sw_vers.txt'
tar -xOzf "$archive" '<sysdiagnose-root>/sysdiagnose.log' | tail -n 100
```

## Extraction Exception: The Unified-Log Archive

`log show --archive` needs the logarchive on disk. Extract only that tree, only after the checks above pass, and only into a new isolated directory. Preserve the original archive and record the extraction in the report.

```zsh
archive='logs/sysdiagnose_<timestamp>_<suffix>.tar.gz'

work_dir=$(mktemp -d /private/tmp/mongoose-sysdiagnose.XXXXXX)
tar -xzf "$archive" -C "$work_dir" '<sysdiagnose-root>/system_logs.logarchive'
find "$work_dir" -mindepth 1 -maxdepth 2 -print
```

If unsafe member paths appear, do not extract. If archive links exist, inspect their targets and do not extract any link that resolves outside the isolated root. If the input is already extracted, use it in place; do not create another copy. Set `sysdiag_root` only after confirming the exact root.

## Inventory And Unified Logs

```zsh
# Already-extracted input: use it in place.
sysdiag_root='/path/to/sysdiagnose_<timestamp>_<suffix>'

# Map top-level contents, sizes and formats.
find "$sysdiag_root" -mindepth 1 -maxdepth 2 -exec stat -f '%z bytes\t%N' {} \;
find "$sysdiag_root" -mindepth 1 -maxdepth 1 -type f -exec file {} \;
find "$sysdiag_root" -type f \( -name '*.ips' -o -name '*.panic' -o -name '*spindump*' -o -name 'sample-*.txt' \) -print

# Review collection completion and task failures separately from host findings.
tail -n 100 "$sysdiag_root/sysdiagnose.log"
for diag_dir in "$sysdiag_root/errors" "$sysdiag_root/summaries"; do
  if [[ -d "$diag_dir" ]]; then
    find "$diag_dir" -maxdepth 2 -type f -print
  else
    print -r -- "missing\t$diag_dir"
  fi
done

# Point at the logarchive: in place, or under $work_dir after extraction.
logarchive="$sysdiag_root/system_logs.logarchive"

# Query unified logs with an incident-bounded window, rendered in endpoint local time.
/usr/bin/log show --archive "$logarchive" \
  --timezone '<Area/City>' \
  --start 'YYYY-MM-DD HH:MM:SS' \
  --end 'YYYY-MM-DD HH:MM:SS' \
  --style compact \
  --predicate 'messageType == fault OR messageType == error'

# MDM focus: the MDM client and managed-client subsystem.
/usr/bin/log show --archive "$logarchive" \
  --timezone '<Area/City>' \
  --start 'YYYY-MM-DD HH:MM:SS' \
  --end 'YYYY-MM-DD HH:MM:SS' \
  --style compact \
  --predicate 'process == "mdmclient" OR subsystem == "com.apple.ManagedClient"'

# Prefer a process or subsystem predicate when the symptom identifies one.
/usr/bin/log show --archive "$logarchive" \
  --timezone '<Area/City>' \
  --start 'YYYY-MM-DD HH:MM:SS' \
  --end 'YYYY-MM-DD HH:MM:SS' \
  --style compact \
  --predicate 'process == "<process-name>" OR subsystem == "<subsystem>"'
```

Do not start with an unbounded dump of the entire logarchive. Broad error and fault counts are triage signals, not root-cause proof. Record every predicate, time window and relevant command with the findings.

Prefer `rg` for focused text searches. Use `head`, `tail`, `sed`, `awk`, `file`, `wc`, `stat`, `plutil`, `zipinfo`, `unzip -l`, `unzip -p`, `unzip -t`, `gzcat` and read-only `sqlite3` queries to characterize large inputs before broad searches. Do not execute programs, scripts or binaries found inside captures. Avoid commands that rewrite, normalize or alter raw evidence.
