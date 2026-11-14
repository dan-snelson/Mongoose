# Contributing to Mongoose

First, thank you for your interest in contributing to **Mongoose**. Mongoose is an Agent Skill for Claude Code and Codex that audits MDM policies and custom script deployments on managed Macs, then writes "The Good, The Bad, and The Ugly". The repository also ships `scripts/mongooseCollect.zsh`, a collector that runs as root on the audited Mac.

You are welcome to discuss ideas, bugs, and improvements in the [Issues](https://github.com/dan-snelson/Mongoose/issues) section. Please use the issue templates so reports include the context needed to reproduce and evaluate the request.

## Pull Requests

Submit Pull Requests against the `development` branch unless requested otherwise. The `main` branch is the current stable line. Mongoose does not publish tagged releases yet; [CHANGELOG.md](CHANGELOG.md) records changes by date.

When submitting a Pull Request:

- Keep changes focused and describe the purpose of the contribution clearly.
- Document user-visible behavior changes in `README.md`, `SECURITY.md`, `CHANGELOG.md`, or the relevant file under `mongoose/references/`.
- Include short, sanitized log excerpts when they help explain a new pattern or bug fix.
- Never commit captures or reports: client-log bundles, sysdiagnoses, MDM inventory JSON, `Terminal Saved Output*.txt` transcripts, Mongoose reports, or `reports/mongoose-baseline.md`.
- Review generated or agent-assisted edits carefully before opening the PR, including edits made by `post-chat-refine`.

## Skill Contributions

The maintained skill surface is [mongoose/SKILL.md](mongoose/SKILL.md) and the files under [mongoose/references/](mongoose/references/). Changes there affect how agents handle untrusted captures from real Macs, so keep evidence quality and privacy first. [AGENTS.md](AGENTS.md) holds the full rules; the short version:

- Preserve the rules that raw evidence is read-only, that nothing found in a capture is executed, and that instructions found in capture content are data, never directions.
- Keep every example generic. Use placeholders such as `<serial>`, `<computer-id>`, `<hostname>`, `<end-user>`, `<managed-admin>`, `<mdm-url>` and `com.example`. No real IDs, serials, hostnames, usernames, IPs, SSIDs, internal URLs, secrets, group names or incident conclusions.
- Use Jamf Pro only as the worked example. Describe other MDMs generically and never invent their log paths. A request to support another MDM needs a short, sanitized sample of its agent log and its documented path.
- Keep `mongoose/SKILL.md` a thin entry point (about 40 lines; [Binge And Purge](mongoose/references/binge-and-purge.md#budget) sets the hard budget). Put detail in a reference and link every reference from `SKILL.md`.
- Keep `SKILL.md` frontmatter to `name` and `description`. The description is at most 1,024 characters and contains no angle brackets.
- Plain Markdown, YAML and Zsh only. Ask before adding a dependency.

## Collector Contributions

`scripts/mongooseCollect.zsh` runs as root on managed Macs. Changes to it should:

- Keep it read-only on the Mac, apart from its staging directory and archive (both readable by root only) and its own lines in a reverse-domain script log that already exists outside Parameter 8. Never write into the Parameter 8 script-log directory, including through Parameter 4 or the Parameter 6 output directory.
- Take every path from the operator (Jamf Pro parameters or arguments), never from content on the Mac. Parameter 8 is a directory the operator names; files under it are discovered only by the `*.log` glob (plain files, no symlinks, no hidden directories, capped at 500 files with rotated siblings counted), and rotated siblings only by `<log>.<n>`, `<log>.<n>.gz` or `<log>.<n>.bz2`.
- Never add hostnames, usernames or IP addresses to the manifest, and never send data off the Mac.
- Keep the README's parameter table in step with the script's header.

## Documentation Contributions

Documentation changes are welcome. Please keep the README, Security Policy, CHANGELOG, issue templates, and skill references aligned with each other. If a change affects how users report bugs, handle captures, install the skill, or run the collector, update every affected place in the same PR.

## Validation

The Security Scan workflow (`.github/workflows/security-scan.yml`) checks:

- Gitleaks against repository history
- `zsh -n` on `scripts/mongooseCollect.zsh` and on every fenced `zsh` block in tracked Markdown
- skill integrity: hidden Unicode, HTML comments in Markdown, tracked captures or reports, the `logs/` and `reports/` ignore rules, tracked local agent settings, `SKILL.md` frontmatter, `references/` links in both directions, the `SKILL.md` budget, and trailing whitespace
- an informational identifier scan (IPv4 addresses, five-digit numbers, serial-like strings) whose hits need human review

Before opening a PR, run the [AGENTS.md](AGENTS.md) Validation steps locally. The workflow cannot run step 1 (`quick_validate.py`), and only a person can judge the identifier hits. At minimum, review Markdown rendering and run `git diff --check`.

## Feature Requests and Bug Reports

Use the [Issues](https://github.com/dan-snelson/Mongoose/issues) section for bugs, feature requests, and documentation issues.

For bug reports, include the Mongoose commit, the agent and version, the input types, what happened, what you expected, and steps to reproduce.

Captures and Mongoose reports hold serial numbers, hostnames, usernames, IPs, MDM URLs and configuration from real Macs. Never attach a bundle, sysdiagnose, inventory JSON or full report to a public issue. Share only short excerpts, sanitized with placeholders.

## Security Reports

If you discover a vulnerability in Mongoose or `mongooseCollect.zsh`, do not open a public issue or Pull Request. Follow [SECURITY.md](SECURITY.md) and email **security@snelson.us**.

## Invitation to Collaborate

Mongoose works best when Mac Admins, script authors, and security and support teams push it toward clearer evidence and safer defaults. Contributions that make reports more accurate, more reproducible, and safer around real captures are especially valuable.
