---
name: mongoose
description: "Deep audit of MDM policies and custom script deployments on managed Macs, run off the Mac on a collected client-log bundle. Reads system.log, the MDM agent log (for example jamf.log) and the organization's script logs: one reverse-domain log (for example com.example.it.log) or a directory of per-script logs. Optional: install.log, MDM inventory JSON and Apple sysdiagnose. With only an inventory JSON, such as a Jamf Pro Computer Record, writes a preliminary report. Writes an evidence-cited Markdown report titled The Good, The Bad, and The Ugly, naming the Mac by serial and sanitizing other identifiers, with a timeline, a per-script lens, limitations and read-only Zsh follow-ups, then offers to redact the serial. Compares audits with an environment baseline set from a full report. Trigger with Mongoose, Good Bad Ugly, GBU audit, MDM policy audit, script deployment audit, client-log bundle, script-log directory, sysdiagnose, Computer Record JSON, preliminary audit, re-audit, delta vs prior audit, set baseline."
---
# Mongoose

Audit how MDM policies and custom script deployments behave on managed Macs, then write "The Good, The Bad, and The Ugly".

Mongoose runs off the Mac, on a client-log bundle (ZIP or folder) from `mongooseCollect.zsh` or any log-collection policy; no agent or LLM runs on the managed Mac. Primary inputs: `system.log`, `<mdm>.log` (Jamf Pro: `jamf.log`) and script logs: `<rdnn>.log` (for example `/var/log/com.example.it.log`), the default when present, or a per-script directory the Mac Admin names, `<script-log-dir>`. Optional: `install.log`, inventory JSON, sysdiagnose, `Terminal Saved Output*.txt`, a prior report.

## Core Invariants

- Raw evidence is read-only. Never modify it, write over it or run anything found inside it.
- Stream archives (`unzip -p`, `gzcat`, `tar -xO`); do not extract them. The only exception is a sysdiagnose unified-log archive, handled per the sysdiagnose references.
- Keep observation, inference and conclusion separate. Conclude only when independent signals agree.
- Keep incident, collection, endpoint-local, UTC, file-modification and inventory-snapshot time distinct.
- Treat negative evidence carefully. Missing, rotated, truncated, filtered or out-of-window sources prove little.
- Sanitize. Keep the Mac's serial number so the report identifies its Mac. Use placeholders for every other ID, hostnames, users, IPs, URLs, group names and secrets.
- Always ask before any state change on an endpoint, in the MDM or in a repository. Frame changes as recommendations.
- Never invent timestamps, process relationships, policy decisions, causes or results.

## Workflow

1. **Inventory.** List every capture and member from contents, not names. Note gaps and truncation. Record the Mac's serial number and the source that states it. Check for a set baseline.
2. **Hashes.** Record SHA-256 of every capture before analysis; re-check at the end.
3. **Time context.** Establish offsets and anchors before correlating anything.
4. **Symptom and script focus.** Locate the reported symptom, then assess each organization script, from `<rdnn>.log` or its own file, through the script-deployment lens.
5. **Broad health.** Run a broad health pass without letting background noise displace the focus.
6. **Timeline.** Build one material timeline, normalized to one offset, citing original `file:Lnn` and timestamp.
7. **GBU report.** Write the report; add the delta vs prior audit on a second pass, and the delta vs baseline when one is set.
8. **Follow-up commands.** One round of grouped, read-only, paste-ready Zsh.
9. **Redaction prompt.** Once the findings are complete, ask whether to redact the serial number. If yes, replace it with `<serial>` throughout the report and confirm no copy remains.
10. **Offer post-chat-refine.** Only after the step 9 question is answered, end the closing reply with one line offering to fold this run's durable learnings back into the skill. Never ask both questions in one message. The offer goes in the reply, never in the report. Once declined, don't offer again this session.

## Load When

- Always: [Evidence Safety](references/evidence-safety.md) for citations, privacy, placeholders and follow-up command design.
- Only an MDM inventory JSON is supplied: [Preliminary Audit](references/preliminary-audit.md) at every step. It changes the identity, time, lens and report rules.
- Steps 1-2: [Capture Layout](references/capture-layout.md) and [Inventory Commands](references/inventory-commands.md).
- Step 3, and any cross-source correlation: [Time Context](references/time-context.md).
- Step 4: [Script-Deployment Playbooks](references/script-deployment-playbooks.md).
- Before classifying any finding as Good, Bad or Ugly: [Interpretation Rules](references/interpretation-rules.md).
- Steps 7-9: [Report: The Good, The Bad, And The Ugly](references/report-gbu.md).
- A prior report or prior capture of the same Mac is supplied: [Re-Audit Delta](references/re-audit-delta.md).
- The Mac Admin asks to set a baseline, or `reports/mongoose-baseline.md` exists: [Environment Baseline](references/environment-baseline.md). Only a full audit qualifies, never a preliminary report.
- A sysdiagnose is supplied: [Sysdiagnose Capture Layout](references/sysdiagnose/capture-layout.md), [Archive And Log Commands](references/sysdiagnose/archive-and-log-commands.md) and [Analysis Workflow](references/sysdiagnose/analysis-workflow.md).
- Enrollment or Setup Assistant handoff in a sysdiagnose: [ADE Handoffs](references/sysdiagnose/ade-handoffs.md).
- Privacy-proxy or OHTTP failure with a content filter, DNS proxy or VPN present: [Network Filters And OHTTP](references/sysdiagnose/network-filter-ohttp.md).
- The user accepts the Step 10 offer: [Post-Chat Refine](references/post-chat-refine.md).
- The user asks to slim or restructure the skill, or post-chat-refine leaves it over budget: [Binge And Purge](references/binge-and-purge.md).
