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

# Stop if any member path is absolute, contains a parent traversal, starts with a
# dash, or holds a control character, a pipe or a character unzip reads as a
# pattern (* ? [ ] \), which would make unzip -p print other members' content.
zipinfo -1 "$bundle" | awk '/^\// || /(^|\/)\.\.($|\/)/ || /^-/ || /[][*?\\|]/ || /[[:cntrl:]]/ { print "UNSAFE\t" $0 }'

# First line, last line and line count per member, in one streamed pass.
# unzip -p removes only the ZIP layer; decompress rotated members before counting.
zipinfo -1 "$bundle" | while IFS= read -r member; do
  [[ "$member" == */ ]] && continue
  print -r -- "== $member"
  case "$member" in
    *.gz)  unzip -p "$bundle" "$member" | gzcat ;;
    *.bz2) unzip -p "$bundle" "$member" | bzcat ;;
    *)     unzip -p "$bundle" "$member" ;;
  esac | awk 'NR == 1 { print } { last = $0 } END { if (NR > 1) print last; print NR " lines" }'
done

# Search one member with line numbers; cite as member:Lnn.
unzip -p "$bundle" '<prefix>-system.log' | rg -n -i 'error|fail|denied|killed'

# Read a rotated member without writing it to disk.
unzip -p "$bundle" '<prefix>-system.log.0.gz' | gzcat | rg -n 'BOOT_TIME|SHUTDOWN_TIME'

# Serial-number candidates, first five per member; cite as member:Lnn.
# The member name is untrusted data: print it, never splice it into a sed or awk program.
zipinfo -1 "$bundle" | while IFS= read -r member; do
  [[ "$member" == */ || "$member" == *.(gz|bz2) ]] && continue
  unzip -p "$bundle" "$member" | rg -n -i -m 5 -e 'serial' -e 'S/N' |
    while IFS= read -r hit; do print -r -- "$member:$hit"; done
done
```

## Directory Bundle

```zsh
capture_dir='logs/<bundle-directory>'

# Files, sizes and formats.
find "$capture_dir" -maxdepth 2 -type f -exec stat -f '%z bytes\t%N' {} \;
find "$capture_dir" -maxdepth 2 -type f -exec file {} \;

# Line counts; decompress rotated logs first, or wc counts compressed bytes.
for f in "$capture_dir"/*(.N); do
  case "$f" in
    *.gz)  print -r -- "$(gzcat "$f" | wc -l | tr -d ' ') $f" ;;
    *.bz2) print -r -- "$(bzcat "$f" | wc -l | tr -d ' ') $f" ;;
    *)     print -r -- "$(wc -l < "$f" | tr -d ' ') $f" ;;
  esac
done

# Coverage window and truncated tails: first and last line per log.
for f in "$capture_dir"/*.log(.N); do
  print -r -- "== $f"
  head -n 1 "$f"
  tail -n 1 "$f"
done

# Search text logs with file names and line numbers.
rg -n -i 'error|fail|denied|killed' "$capture_dir"

# Serial-number candidates, first five per file.
rg -n -i -m 5 -e 'serial' -e 'S/N' "$capture_dir"

# Read rotated logs without extracting them in place.
for gz in "$capture_dir"/*.gz(.N); do
  print -r -- "== $gz"
  gzcat "$gz" | rg -n 'BOOT_TIME|SHUTDOWN_TIME'
done
```

## MDM Inventory JSON

Print key paths, counts, sizes and selected status fields, never the full record or raw extension-attribute values.

```zsh
inventory='logs/<inventory-export>.json'

# Valid JSON prints nothing. jq ships with macOS 15 and later.
jq empty "$inventory"

# Shape: top-level keys with type and size, no values.
jq -r 'to_entries[] | [.key, (.value | type), (.value | if type == "array" or type == "object" then length else "" end)] | @tsv' "$inventory"

# Key paths only, no values: shows what the export holds without printing data.
jq -r 'paths(scalars) | map(tostring) | join(".")' "$inventory" | sort -u | head -n 200

# Key paths that hold a serial number. Disk and certificate serials also match;
# only the hardware or general section names the Mac.
jq -r 'paths(scalars) | map(tostring) | join(".")' "$inventory" | rg -i 'serial'

# Snapshot candidate: a 13-digit epoch in the file name, as UTC. Compare with mtime.
epoch_ms=$(print -r -- "${inventory:t}" | rg -o '[0-9]{13}' | head -n 1)
[[ -n "$epoch_ms" ]] && date -u -r $(( epoch_ms / 1000 )) '+%Y-%m-%dT%H:%M:%SZ'

# Print one key path once you know it is needed.
jq '.<key>.<path>' "$inventory"
```

### Preliminary Audit Projections

For [Preliminary Audit](preliminary-audit.md). Key paths are Jamf Pro API; map them for other shapes.

```zsh
inventory='logs/<computer-id>_response_<epoch-ms>.json'

# Time fields.
jq '{reportDate: .general.reportDate, lastContact: .general.lastContact, lastEnrolledDate: .general.lastEnrolledDate, initialEntryDate: .general.initialEntryDate, mdmProfileExpiration: .general.mdmProfileExpiration, lastSuccessfulAttestation: .security.lastSuccessfulAttestation, profilesInstalled: ([.configurationProfiles[]?.lastInstalled | select(. != null)] | {first: min, last: max})}' "$inventory"

# Management, OS, security, encryption, storage and battery status fields.
jq '{management: (.general | {enrolledViaAutomatedDeviceEnrollment, supervised, userApprovedMdm, declarativeDeviceManagementEnabled, mdmCapable: .mdmCapable.capable, jamfBinaryVersion}), os: (.operatingSystem | {version, build, fileVault2Status}), security: .security, encryption: (.diskEncryption | {individualRecoveryKeyValidityStatus, institutionalRecoveryKeyPresent, fileVault2Enabled, boot: .bootPartitionEncryptionDetails, enabledUsers: (.fileVault2EnabledUserNames | length)}), storage: {bootFreeMB: .storage.bootDriveAvailableSpaceMegabytes, smart: [.storage.disks[]?.smartStatus]}, battery: (.hardware | {batteryHealth, batteryCapacityPercent})}' "$inventory"

# Counts: non-system accounts, profiles, receipts, smart groups, certificates, attachments.
jq '{accounts: ([.localUserAccounts[]? | select((.uid | tonumber? // -1) >= 501)] | length), profiles: (.configurationProfiles | length), receiptsMdm: (.packageReceipts.installedByJamfPro | length), smartGroups: ([.groupMemberships[]? | select(.smartGroup)] | length), certificates: ([.certificates[]? | "\(.certificateStatus)/\(.lifecycleStatus)"] | group_by(.) | map({(first): length}) | add), attachments: [.attachments[]? | {fileType, sizeBytes}]}' "$inventory"

# Extension-attribute lens: collector, type, value bytes and name, largest first. No values.
eas='def eas: [.extensionAttributes[]?, ((.general, .hardware, .operatingSystem, .userAndLocation) | .extensionAttributes[]?)] | .[];'
jq -r "$eas"' eas | [.inputType, .dataType, ((.values // []) | join("\n") | length), .name] | @tsv' "$inventory" | sort -t $'\t' -k3,3nr

# Names only: values that look like an IP or email address, or carry error text.
# Four-part version numbers also match the IP pattern; confirm each hit by hand.
jq -r "$eas"' eas | select((.values // []) | join(" ") | test("\\b([0-9]{1,3}\\.){3}[0-9]{1,3}\\b|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")) | .name' "$inventory"
jq -r "$eas"' eas | select((.values // []) | join(" ") | test("error|not found|no such file|permission denied"; "i")) | .name' "$inventory"
```

Prefer `rg` for focused searches. Use `head`, `tail`, `sed -n`, `awk`, `file`, `wc`, `stat`, `zipinfo`, `unzip -l`, `unzip -p`, `unzip -t`, `gzcat` and `jq` to characterize large inputs before broad searches. For sysdiagnose archives, see [Archive And Log Commands](sysdiagnose/archive-and-log-commands.md).
