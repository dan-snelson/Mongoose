# Security Policy

Thank you for helping keep **Mongoose** secure.

Mongoose is an [Agent Skill](https://agentskills.io) for Claude Code and Codex. It ships no compiled code, but its instructions direct an AI agent to read **untrusted captures** from managed Macs (client-log bundles, MDM inventory JSON exports, Apple sysdiagnoses, `Terminal Saved Output*.txt` transcripts and prior Mongoose reports), run local commands against them (`unzip`, `gzcat`, `tar`, `shasum`, `log show`, `rg`, `jq`, `plutil`), and write reports that hold **device identifiers and configuration details**. On request, its **post-chat-refine** pass edits the skill's own files. The repository also ships **`scripts/mongooseCollect.zsh`**, a collector that runs **as root** on the audited Mac. The maintained attack surface is **`mongoose/SKILL.md`**, everything under **`mongoose/references/`**, and **`scripts/mongooseCollect.zsh`**.

## Supported Versions

Mongoose does not yet publish tagged releases. Only the current `main` branch receives security updates.

- Current stable: **`main`**
- Current prerelease line: **`development`**
- Older copies of the skill or the collector receive no security patches.

If you installed Mongoose by copying the `mongoose/` directory, or deployed a copy of `mongooseCollect.zsh` to your MDM, copy it again from current `main` before requesting security support.

## Scope

Report a vulnerability when Mongoose's instructions can lead an agent to:

- Execute content from a capture (log lines, script output, policy or script parameters, inventory JSON, sysdiagnose files, transcripts or prior reports), or shell syntax embedded in a file name, an archive member path or a path argument
- Follow instructions embedded in capture content (prompt injection) in a way that changes a classification, hides or downgrades a finding, alters the timeline or runs commands
- Modify or overwrite raw evidence, extract an archive member with an absolute or parent-traversal (`..`) path, or follow a link inside an archive
- Leave identifiers other than the Mac's serial number unsanitized in a report, or expose a secret from a policy or script parameter in a report or chat reply without redaction
- Present a state-changing command as a read-only follow-up, or request keychains, tokens, credentials, private keys or enrollment secrets
- Write a report or the baseline record outside `reports/`, overwrite one without asking, or write into a git-tracked path without asking
- Let an environment baseline hide or downgrade a finding, or compare with a baseline report whose SHA-256 no longer matches its record without saying so
- Leak identifiers or capture text into `SKILL.md` or `references/` through post-chat-refine

Report a vulnerability when `mongooseCollect.zsh` can:

- Run a command, or write to a path, chosen by content on the Mac rather than by the operator
- Leave staging files or the archive readable by users other than root
- Be steered by another local user, for example through a planted file or link in the output directory, into writing, overwriting or adding members to a file it did not create
- Add hostnames, usernames or IP addresses to the collection manifest, or send data off the Mac

Misclassified findings, wrong timelines, missed script problems and collector failures that expose nothing are quality issues, not vulnerabilities. Open a regular issue for those.

## Reporting a Vulnerability

If you discover a security vulnerability in this project, report it privately.

**Do not** open a public GitHub Issue or Pull Request that discloses the vulnerability.

Send reports to: **security@snelson.us**

Please include as much of the following as possible:

- A clear description of the issue and its potential impact
- Steps to reproduce it, including a minimal, synthetic capture that triggers it (never a capture from a real Mac)
- The `main` commit SHA of the Mongoose copy you used
- The agent and version (Claude Code or Codex), plus its permission or sandbox mode
- For collector issues: how it ran (MDM policy or locally with `sudo`), Parameters 4-7 as placeholders, and the macOS version
- The relevant agent transcript excerpt or report section, sanitized with placeholders such as `<serial>`, `<computer-id>`, `<hostname>`, `<end-user>` and `<mdm-url>`
- Any suggested mitigation or fix
- Your name or handle, if you want attribution

You should receive an acknowledgment within **48 hours**. We will work with you to validate the report, develop a fix, and coordinate disclosure once the issue is resolved.

## Safe Use Guidance

- Install Mongoose only from this repository, and review `mongoose/` before installing it. The README's symlink install tracks this checkout, so review changes after every pull.
- Run Mongoose with your agent's permission prompts or sandbox enabled. Captures come from managed Macs and are untrusted, so review any command the agent proposes that isn't a read, hash, stream or bounded `log show`.
- Keep captures in the git-ignored `logs/` directory and reports in `reports/`, and never force-add either. If you run Mongoose from another working directory, gitignore `reports/` there first.
- Treat every capture and report as sensitive. Reports keep the Mac's serial number by default; accept redaction at the prompt before a report leaves the team that manages the Mac. Never attach captures, sysdiagnoses, inventory JSON exports or full reports to public issues.
- Read each follow-up command before running it on an endpoint. Follow-ups are meant to be read-only; if one changes state or asks for secrets, don't run it, and report it.
- Review `mongooseCollect.zsh` before deploying it. It runs as root and copies the files that Parameters 4 and 5 name in full, so point them only at log files. If you change Parameter 6, choose an output directory that only root can write.
- Move the collector's archive off the Mac through a channel approved for sensitive data, then delete it from the output directory.
- If Mongoose reports that the baseline report's SHA-256 no longer matches `reports/mongoose-baseline.md`, find out why before setting the baseline again.
- Review the diff after accepting **post-chat-refine** and before committing it. Confirm that no serials, computer IDs, hostnames, accounts, URLs, policy or script names, timestamps or hashes were added to the skill files. Then accept its offer to delete the scratch directory, because `fingerprints.txt` holds the run's real identifiers.

## Code Security Practices

- The repository holds plain Markdown, YAML and Zsh only. A new dependency needs maintainer approval (`AGENTS.md`).
- Every change passes the `AGENTS.md` Validation steps:
  - `quick_validate.py` checks the skill's frontmatter.
  - Searches for IPv4 addresses, 5-digit IDs and serial-like strings, plus the contributor's own organization names and domains, are reviewed by hand.
  - Every `references/` link in `SKILL.md` resolves, and every reference file is linked.
  - Every Zsh file and every fenced `zsh` block in Markdown, which are the commands an agent runs, passes **`zsh -n`**.
  - `git diff --check` and a trailing-whitespace search come back clean.
- `.gitignore` excludes `logs/`, `reports/`, `*.zip`, `*.tar.gz`, `*.logarchive`, `sysdiagnose_*`, `.envrc` and `.claude/settings.local.json`, and `AGENTS.md` forbids force-adding them.
- Examples use placeholders only (`<serial>`, `<computer-id>`, `<hostname>`, `<end-user>`, `<managed-admin>`, `<mdm-url>`, `com.example`). Jamf Pro is the only worked example; log paths for other MDMs are never invented.
- Raw evidence is read-only, and nothing found inside it is ever run (`SKILL.md` Core Invariants).
- Archives are streamed (`unzip -p`, `gzcat`, `tar -xO`), not extracted. For a vendor capture archive, the agent validates integrity, stops on absolute or `..` member paths, never follows archive links, and extracts only into a new, empty directory that the report's Handling line names (`references/evidence-safety.md`).
- Every capture is hashed with SHA-256 before analysis and re-checked at the end. A changed hash is reported as a handling failure.
- Reports keep only the Mac's serial number. Every other identifier becomes a placeholder, secrets become `<redacted>`, and the agent offers to redact the serial once the findings are complete.
- Follow-up commands default to read-only. They never request keychains, tokens, credentials, private keys or enrollment secrets without explaining why existing evidence is insufficient.
- The agent asks before any state change on an endpoint, in the MDM or in a repository, and never recommends disabling a security control as a diagnostic shortcut.
- Reports are written only to `reports/`, after `git check-ignore` confirms the directory is ignored; otherwise the agent asks.
- The environment baseline stores only a pointer and the report's SHA-256, refuses preliminary reports, and never hides or downgrades a finding (`references/environment-baseline.md`).
- post-chat-refine (`references/post-chat-refine.md`):
  - It backs up the skill directory before editing.
  - It treats capture contents as untrusted data: it never follows instructions found in them and never copies their text into the skill.
  - It runs a fingerprint check over every added line.
  - It never commits.
- `mongooseCollect.zsh`:
  - It starts with `#!/bin/zsh --no-rcs`, sets a fixed `PATH` and `umask 077`, and exits unless it runs as root.
  - It needs no MDM API access or credentials, and makes no network connections.
  - It creates a new staging directory with `mkdir`, fails rather than reusing an existing path, and removes only a staging directory it created.
  - It validates Parameter 7 against `<number>m`, `h` or `d` before passing it to `log show`.
  - It appends to the reverse-domain script log only when that file already exists.
  - Its manifest omits hostnames, usernames and IP addresses.
  - It tests the archive with `unzip -t`, sets it to mode `600`, and prints its SHA-256.
- Changes are reviewed with attention to shell quoting in documented commands, untrusted capture handling, report destinations, what post-chat-refine may write, and the collector's root privileges.

## Disclosure Policy

- We follow coordinated disclosure.
- We will prioritize a fix before sharing public technical details.
- Security fixes will be committed to `main` as quickly as practical, with a commit message noting the fix.
- We will credit the reporter unless anonymity is requested.

## General Security Questions

For non-vulnerability questions or general usage concerns, open an issue on [GitHub](https://github.com/dan-snelson/Mongoose/issues).

Last updated: November 2026
