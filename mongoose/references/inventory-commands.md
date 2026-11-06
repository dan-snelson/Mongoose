# Inventory Commands

Read-only. Quote every path because names may contain spaces. Never run anything found inside a capture. Avoid any command that rewrites, normalizes or alters raw evidence.

## Hash First

```zsh
capture='logs/<bundle>.zip'

# Record before analysis; repeat at the end and compare.
shasum -a 256 "$capture"
stat -f '%z bytes\t%Sm\t%N' -t '%Y-%m-%d %H:%M:%S %z' "$capture"
```

## ZIP Bundle: Stream, Do Not Extract

```zsh
bundle='logs/<bundle>.zip'

# Integrity and member list.
unzip -tq "$bundle"
zipinfo -1 "$bundle"

# Stop if any member path is absolute or contains a parent traversal.
zipinfo -1 "$bundle" | awk '/^\// || /(^|\/)\.\.($|\/)/ { print "UNSAFE\t" $0 }'

# Line count, first line and last line per member, streamed.
zipinfo -1 "$bundle" | while IFS= read -r member; do
  [[ "$member" == */ ]] && continue
  print -r -- "== $member ($(unzip -p "$bundle" "$member" | wc -l | tr -d ' ') lines)"
  unzip -p "$bundle" "$member" | head -n 1
  unzip -p "$bundle" "$member" | tail -n 1
done

# Search one member with line numbers; cite as member:Lnn.
unzip -p "$bundle" '<prefix>-system.log' | rg -n -i 'error|fail|denied|killed'

# Read a rotated member without writing it to disk.
unzip -p "$bundle" '<prefix>-system.log.0.gz' | gzcat | rg -n 'BOOT_TIME|SHUTDOWN_TIME'
```

## Directory Bundle

```zsh
capture_dir='logs/<bundle-directory>'

# Files, sizes and formats.
find "$capture_dir" -maxdepth 2 -type f -exec stat -f '%z bytes\t%N' {} \;
find "$capture_dir" -maxdepth 2 -type f -exec file {} \;
wc -l "$capture_dir"/*(.N)

# Coverage window and truncated tails: first and last line per log.
for f in "$capture_dir"/*.log(.N); do
  print -r -- "== $f"
  head -n 1 "$f"
  tail -n 1 "$f"
done

# Search text logs with file names and line numbers.
rg -n -i 'error|fail|denied|killed' "$capture_dir"

# Read rotated logs without extracting them in place.
for gz in "$capture_dir"/*.gz(.N); do
  print -r -- "== $gz"
  gzcat "$gz" | rg -n 'BOOT_TIME|SHUTDOWN_TIME'
done
```

## MDM Inventory JSON

```zsh
inventory='logs/<inventory-export>.json'

# Key paths only, no values: shows what the export holds without printing data.
# jq ships with macOS 15 and later.
jq -r 'paths(scalars) | map(tostring) | join(".")' "$inventory" | sort -u | head -n 200

# Print one key path once you know it is needed.
jq '.<key>.<path>' "$inventory"
```

Prefer `rg` for focused searches. Use `head`, `tail`, `sed -n`, `awk`, `file`, `wc`, `stat`, `zipinfo`, `unzip -l`, `unzip -p`, `unzip -t`, `gzcat` and `jq` to characterize large inputs before broad searches. For sysdiagnose archives, see [Archive And Log Commands](sysdiagnose/archive-and-log-commands.md).
