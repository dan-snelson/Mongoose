# Preliminary Audit: Inventory JSON Only

Use when an MDM inventory JSON is the only capture, for example a Jamf Pro Computer Record, and no client-side logs are available. Run the `SKILL.md` workflow against the JSON. The result is a preliminary report: it shows state at one snapshot and never replaces the full audit.

## Recognize The Export

- Detect the shape from key paths, not the file name. Print key paths, not values ([Inventory Commands](inventory-commands.md#mdm-inventory-json)).
- **Jamf Pro API Computer Record** (the worked example): top-level camelCase sections such as `general`, `hardware`, `operatingSystem`, `security`, `diskEncryption`, `storage`, `localUserAccounts`, `applications`, `configurationProfiles`, `certificates`, `packageReceipts`, `groupMemberships`, `extensionAttributes` and `attachments`. Extension attributes also nest inside `general`, `hardware`, `operatingSystem` and `userAndLocation`.
- **Jamf Pro Classic API:** one `computer` object with snake_case keys. Map each check below by key-path search.
- **Other MDMs:** find the equivalent fields by key-path search. Never assume paths.
- Record every section as present, empty or absent. An API request can limit sections, and an empty array can mean "not collected" rather than "none".
- File names such as `<computer-id>_response_<epoch-ms>.json` are common. The prefix is sensitive; the epoch is a download-time candidate.

## Device Identity

- Take the Mac's serial from the hardware section (Jamf Pro API: `.hardware.serialNumber`). Cite the key path and snapshot time.
- A `serial` key-path search also lists disk serials (`.storage.disks[].serialNumber`) and certificate serials (`.certificates[].serialNumber`). Neither identifies the Mac.
- Cross-check any other field or extension attribute that states the serial. Disagreement means stop and ask.
- Computer ID, UDID, management ID, provisioning UDID and MAC addresses are sensitive. Use placeholders from [Evidence Safety](evidence-safety.md).

## Time Context

JSON timestamps are usually UTC (`Z`). Normalize the timeline to UTC and say so.

| Time | Jamf Pro API source | Meaning |
|---|---|---|
| Snapshot | Export field; else file-name epoch that agrees with file mtime; else ask | When the record was read. Name the report from it |
| Last inventory | `.general.reportDate` | Inventory values and extension attributes are as of this time, not the snapshot |
| Last contact | `.general.lastContact`, `.general.lastCheckIn` | Agent check-in. Can be newer than the last inventory |
| Enrollment | `.general.lastEnrolledDate`, `.general.initialEntryDate` (date only) | Start of the managed life; measure ages from it |
| MDM profile expiry | `.general.mdmProfileExpiration` | Future date expected |
| Attestation | `.security.lastAttestationAttempt`, `.security.lastSuccessfulAttestation` | Device attestation |
| Profile installs | `.configurationProfiles[].lastInstalled` | Spread of profile delivery |
| Certificates | `.certificates[].issuedDate`, `.expirationDate` | Validity window |
| Date-valued extension attributes | `values` | Script-defined format and offset. Treat as unanchored endpoint-local time |

Report the inventory age (snapshot minus last inventory) and the enrollment age at snapshot. A stale inventory lowers confidence in every inventory-derived finding.

## Field Map

Key paths are Jamf Pro API. Good, Bad and Ugly follow [Interpretation Rules](interpretation-rules.md) and the classes in [Report: The Good, The Bad, And The Ugly](report-gbu.md).

| Area | Key paths | Good when | Bad or Ugly when | Caveat |
|---|---|---|---|---|
| Management | `.general`: `enrolledViaAutomatedDeviceEnrollment`, `supervised`, `userApprovedMdm`, `mdmCapable.capable`, `declarativeDeviceManagementEnabled`, `mdmProfileExpiration`, `jamfBinaryVersion` | All true; profile expiry well in the future | Not MDM capable or profile expired: Ugly. Not supervised or no user approval: Bad | Agent version: record; compare only with a stated target |
| Freshness | `.general.lastContact`, `.general.reportDate` | Both recent at snapshot | Old contact or inventory: Bad, and lower confidence everywhere | Normal check-in and inventory cadences differ |
| OS | `.operatingSystem`: `version`, `build`, `supplementalBuildVersion` | Matches a target stated in the evidence | Behind that target: Bad | Never assert "latest" from memory; compare with an extension attribute or mark unverified |
| Security | `.security`: `sipStatus`, `gatekeeperStatus`, `secureBootLevel`, `externalBootLevel`, `firewallEnabled`, `autoLoginDisabled`, `remoteDesktopEnabled`, `activationLockEnabled`, `recoveryLockEnabled`, `bootstrapTokenEscrowedStatus`, `attestationStatus`, `xprotectVersion` | Protections on; token escrowed; attestation success | SIP or Gatekeeper off, reduced secure boot or auto-login on: Ugly. Firewall off, token not escrowed or attestation failing: Bad | Remote Desktop and external boot may be by design; ask the owning team. Apple silicon and Intel report boot policy differently |
| Encryption | `.operatingSystem.fileVault2Status`; `.diskEncryption`: `bootPartitionEncryptionDetails`, `individualRecoveryKeyValidityStatus`, `institutionalRecoveryKeyPresent`, `fileVault2EnabledUserNames` (count only), `fileVault2Enabled` | Boot volume encrypted at 100 percent with a valid escrowed key | Unencrypted boot volume: Ugly. Invalid or missing key: Bad | Fields can disagree. Cite each one and conclude nothing until a second collector agrees |
| Storage and hardware | `.storage.bootDriveAvailableSpaceMegabytes`, `.storage.disks[].smartStatus`, `.hardware.batteryHealth`, `.hardware.batteryCapacityPercent` | Space free; SMART verified; battery normal | Low space or failing SMART: Bad | Non-boot APFS volumes report their own encryption states |
| Local accounts | `.localUserAccounts[]`: `uid`, `userAccountType`, admin flags when present | Expected count of non-system accounts | Unexpected admins or accounts: Bad | Count accounts with UID 501 or higher; never list names |
| Profiles | `.configurationProfiles[]`: `profileIdentifier`, `displayName`, `lastInstalled` | All installed, in a tight window after enrollment | Missing `lastInstalled` or duplicate identifiers: Bad | Identifiers carry the organization's reverse domain; use `com.example` |
| Certificates | `.certificates[]`: `certificateStatus`, `lifecycleStatus`, `expirationDate` | Active and valid | Active and expired, or expiring within 30 days: Bad | Expired and inactive is usually a replaced certificate |
| Policy footprint | `.packageReceipts`: `installedByJamfPro`, `installedByInstallerSwu`, `cached`; `.groupMemberships[]` | Expected packages present | Expected package missing: Bad | Receipts show installs, not policy runs. Group names become `<group>` |
| Attachments | `.attachments[]`: `fileType`, `sizeBytes` | Not graded | Not graded | May hold an earlier client-log bundle. Report type and size only |
| Low priority | `.contentCaching`, `.services`, `.applications` | Not graded unless relevant | Content caching failing where the organization intends caching: Bad | Report counts unless the symptom points here |

## Extension-Attribute Lens

Script extension attributes are the JSON-visible footprint of custom scripts. This lens stands in for the script-deployment lens in [Report: The Good, The Bad, And The Ugly](report-gbu.md). One row per script extension attribute, plus any directory or pop-up attribute with a finding.

- **Value state:** populated, empty, or error text such as "command not found" or "No such file". An empty value often means the script printed no `<result>` tag.
- **Shape vs type:** an integer or date `dataType` with a value that is not one.
- **Size:** values of several kilobytes inflate every inventory upload.
- **Freshness:** date-valued attributes far older than the last inventory.
- **Privacy:** IP addresses, SSIDs, geolocation, account names, email addresses, directory group lists or free-text user reasons. The value leaves the Mac at every inventory. Report Bad for privacy review; report Ugly when a value holds a secret or credential. Name the attribute; never quote the value.
- **Not observable:** exit codes, duration, concurrency, triggers and policy parameters need `<mdm>.log`.

| Extension attribute | Collector | Value state | Shape vs type | Size | Freshness | Privacy | Exit, duration, trigger |
|---|---|---|---|---|---|---|---|
| `<ea-name>` | script / directory / pop-up | populated / empty / error text | ok / mismatch | `<bytes>` | `<age at last inventory>` | none / `<types>` | Not observable (needs `<mdm>.log`) |

## Confidence

- One snapshot shows state, not trend or cause.
- Label most findings Obs and Inf. Write a Conclusion only when different collectors agree, for example an OS status field, a script extension attribute and key-escrow state. Two fields from the same collector are not independent.

## Not Observable From Inventory Alone

State these under Limitations in every preliminary report: policy execution and triggers, script runs, exit codes and duration, `<rdnn>.log` content, boots and shutdowns, `install.log` activity, crashes and unified-log events. In Jamf Pro, policy logs and management history are separate records, not part of the Computer Record.

## Commands

Read-only JSON commands, including the projections for this lens and the field map, live in [Inventory Commands](inventory-commands.md#mdm-inventory-json).

## Report Deltas

Follow [Report: The Good, The Bad, And The Ugly](report-gbu.md) with these changes:

- **File:** `reports/mongoose-gbu-preliminary-<YYYY-MM-DD-HHMMSS>.md`, named from the snapshot time in UTC.
- **Title:** `# Mongoose (Preliminary): The Good, The Bad, and The Ugly`.
- **Scope:** inventory JSON only; client-side logs not reviewed. Evidence window: enrollment to snapshot, with the last-inventory time.
- **Evidence and method:** replace the Members table with a Sections table: section, items, notes (empty, absent, stale).
- **Time context:** one row per time field above, normalized to UTC.
- **Lens:** the extension-attribute lens replaces the script-deployment lens.
- **Next steps:** P1 is always to collect the client-log bundle, or retrieve an attachment that holds one, and run the full audit with this report as the prior report ([Re-Audit Delta](re-audit-delta.md)). Follow-up commands confirm inventory values on the Mac:

```zsh
# Group 1: confirm OS, encryption and protection state the inventory reported.
# sudo: no. Return: all output. Stop: finishes on its own.
sw_vers
fdesetup status
csrutil status
spctl --status
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Group 2: confirm MDM enrollment and that the primary logs exist for a full audit.
# sudo: no. Return: all output. Stop: finishes on its own.
profiles status -type enrollment
ls -l '/var/log/system.log' '/var/log/<mdm>.log' '/var/log/<rdnn>.log'
```
