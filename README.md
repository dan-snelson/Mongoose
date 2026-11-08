# Mongoose
Mongoose delivers a deep, under-the-hood audit of your MDM policies, focusing on how custom script deployments affect your Mac fleet.

This AI skill analyzes key logs …
- `/var/log/system.log`
- `/var/log/<mdm>.log` (i.e., Jamf Pro's `/var/log/jamf.log`)
- `/var/log/<rdnn>.log` (i.e., your organization's reverse-domain script log, for example `/var/log/org.churchofjesuschrist.log`)

… then produces a clear Markdown report structured as “The Good, The Bad, and The Ugly.”

## What it reads

| Input | Required | What it shows |
|---|---|---|
| `/var/log/system.log` and rotated `.gz` files | Yes | Boots, shutdowns, launchd and daemon activity |
| `/var/log/<mdm>.log` | Yes | Your MDM agent's log. |
| `/var/log/<rdnn>.log` | Yes | Your organization's reverse-domain script log, for example `/var/log/org.churchofjesuschrist.log` |
| `/var/log/install.log` | Optional | Package and software-update activity |
| MDM inventory JSON export | Optional | Server-side state at snapshot time. On its own, enough for a preliminary report |
| Apple sysdiagnose | Optional | Unified logs, crashes, configuration and system state |
| A prior Mongoose report | Optional | Turns the run into a re-audit with a delta table |

These usually arrive as a client-log bundle: a ZIP or directory of copied `/var/log` files, often prefixed with a device ID and a collection timestamp. Mongoose detects the layout from the contents, not the names.

## What it produces

One Markdown report, `reports/mongoose-gbu-<YYYY-MM-DD-HHMMSS>.md`, named from the capture's collection timestamp:

- **Header and method:** scope, evidence window, capture hashes, and how the evidence was handled.
- **Time context:** how each source's timestamps were normalized, and one cited timeline.
- **The Good, The Bad, The Ugly:** numbered findings, each split into observation, inference and conclusion, with `file:line` citations.
- **Script-deployment lens:** per script, versioned logging, time offsets, exit codes and duration, concurrency, redundant runs, secrets in policy parameters, personal data in uploaded logs, and log noise.
- **Limitations and next steps:** prioritized recommendations for the owning teams, and one round of read-only Zsh follow-up commands.

A re-audit adds a delta table (Fixed, Improved, Unchanged, Worse, Not observable) and re-test checklist results.

With only an MDM inventory JSON, such as a Jamf Pro Computer Record, Mongoose writes a preliminary report, `reports/mongoose-gbu-preliminary-<YYYY-MM-DD-HHMMSS>.md`, named from the snapshot time. It grades management, security, encryption, certificates, profiles and extension attributes at that one snapshot, marks policy and script behavior Not observable, and makes collecting client-side logs for the full audit its first next step.

## Install

Mongoose follows the open Agent Skills format; the `mongoose/` directory works with Claude Code and Codex unchanged. A symlink keeps the installed skill in step with this checkout.

```zsh
cd /path/to/Mongoose

# Claude Code
mkdir -p ~/.claude/skills
ln -s "$PWD/mongoose" ~/.claude/skills/mongoose

# Codex
mkdir -p ~/.agents/skills
ln -s "$PWD/mongoose" ~/.agents/skills/mongoose
```

## Collect

[`scripts/mongooseCollect.zsh`](scripts/mongooseCollect.zsh) builds the client-log bundle on the Mac being audited. Run it as root. It needs no MDM API access and no credentials.

It copies `system.log`, the MDM agent log and your reverse-domain script log, with their rotated files. When present, it also copies `install.log`, App Auto-Patch logs and the BeyondTrust EPM `audit.log`. When Jamf Pro Self Service+ is installed, it exports Self Service+ entries from Unified Logging with `log show`, finding the app by bundle ID `com.jamf.selfserviceplus`, so a renamed app still counts. It adds a collection manifest: collection time with UTC offset, time zone, macOS build, boot time, serial number, and each member's size, modification time and SHA-256.

| Jamf Pro parameter | Value | Default |
|---|---|---|
| 4 | Reverse-domain script log, for example `/var/log/org.churchofjesuschrist.log` | None. When unset, the bundle lacks it and the script warns |
| 5 | MDM agent log | `/var/log/jamf.log` |
| 6 | Output directory | `/var/tmp` |
| 7 | Self Service+ log window, as passed to `log show --last`: `<number>m`, `h` or `d` | `7d` |

```zsh
# Run locally. Jamf Pro reserves parameters 1-3.
sudo zsh scripts/mongooseCollect.zsh / '' '' /var/log/org.churchofjesuschrist.log
```

The result is `/var/tmp/mongoose-<serial>-<YYYY-MM-DD-HHMMSS>.zip`, readable by root only. Each member is named `<serial>-<YYYY-MM-DD-HHMMSS>-<log>`. The script prints the archive's path and SHA-256, and appends its own log lines to the reverse-domain script log only when that file already exists. Moving the archive off the Mac is up to you. It holds the same sensitive data as any capture.

## Usage

Put captures in a git-ignored `logs/` directory, then ask:

> Run a Mongoose GBU audit on `logs/<bundle>.zip`. Our script log is `org.churchofjesuschrist.log`.

With only a Computer Record JSON:

> Run a preliminary Mongoose audit on `logs/<computer-id>_response_<epoch-ms>.json`.

For a second pass:

> Re-audit with Mongoose. Baseline: `logs/<baseline>.zip` and `reports/mongoose-gbu-<timestamp>.md`. New: `logs/<new>.zip`. Stated changes: <list>.

In Codex, you can also call it by name: `$mongoose`.

After the redaction question, the reply ends with a one-line offer to run post-chat-refine, which folds the run's durable lessons back into `mongoose/SKILL.md` and its references as generic guidance. Accepting edits the skill files in place, with serials, IDs, hostnames, accounts, URLs, policy and script names and other identifiers stripped. With the symlink install above, that is this checkout, so review `git diff` before committing.

## Privacy

Captures and reports hold identifiers, paths and configuration from real Macs. Keep them local. This repo's `.gitignore` excludes `logs/`, `reports/`, archives and sysdiagnose trees. Mongoose reads evidence without changing it, never runs anything found in a capture, names each report's Mac by serial number, replaces other identifiers with placeholders, and offers to redact the serial once the findings are done.

## License

MIT. See [LICENSE](LICENSE).
