# AGENTS.md

## Purpose

This repo holds Mongoose, an organization-neutral Agent Skill. It audits MDM policies and custom script deployments on managed Macs and writes a Markdown report titled "The Good, The Bad, and The Ugly".

## Skill Location

- `mongoose/SKILL.md`: entry point. Keep it thin (about 40 lines): when to use, core invariants, workflow, which reference to load when.
- `mongoose/references/`: detail, loaded on demand. Link every file from `SKILL.md`.
- `mongoose/agents/openai.yaml`: Codex display metadata.
- `scripts/mongooseCollect.zsh`: client-side collector that builds the `.zip` bundle Mongoose reads. It sits outside the skill; `SKILL.md` does not link it.

## Rules

- Never commit captures or reports. `logs/`, `reports/`, archives and sysdiagnose trees are git-ignored; never force-add them.
- Keep every example generic. Use placeholders such as `<computer-id>`, `<serial>`, `<hostname>`, `<end-user>`, `<managed-admin>`, `<mdm-url>` and `com.example`. No real IDs, serials, hostnames, usernames, IPs, SSIDs, internal URLs, secrets, group names or incident conclusions.
- Use Jamf Pro only as the worked example. Mention other MDMs generically and never invent their log paths. Treat community tools as optional examples, never as assumed components.
- Keep `SKILL.md` frontmatter to `name` and `description`. The description is at most 1024 characters and contains no angle brackets.
- Run `zsh -n` on any Zsh you add or change, including fenced `zsh` blocks in Markdown.
- Keep changes narrow. Plain Markdown, YAML and Zsh only; ask before adding a dependency.
- Review `git diff --check` before finishing.

## Validation

The Security Scan workflow (`.github/workflows/security-scan.yml`) runs steps 2-5 on every push and pull request to `main` and `development`; step 2 lands in its job summary for human review. Still run them locally before finishing, and run step 1 yourself, because CI has no `quick_validate.py`.

1. `python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py mongoose` passes. It needs a Python 3 with PyYAML.
2. No identifying data. Search for your own organization's names and domains, then review every hit of these by hand:

   ```zsh
   rg -n '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' .
   rg -n '\b[0-9]{5}\b' .
   rg -n '\b[A-Z0-9]{10,12}\b' .
   ```

3. Every `references/` link in `SKILL.md` resolves, and every file under `mongoose/references/` is linked from `SKILL.md`.
4. Every fenced `zsh` block, extracted to a temporary file, passes `zsh -n`.
5. `git status --short` lists only intended files, and `rg -n '[ \t]+$'` finds no trailing whitespace.
