---
name: mongoose
description: Deep audit of MDM policies and custom script deployments on managed Macs. Reads system.log, the MDM agent log (for example jamf.log) and the organization's reverse-domain script log (for example com.example.it.log), plus optional install.log, an MDM inventory JSON export and an Apple sysdiagnose, usually from a client-log bundle. Produces an evidence-cited Markdown report titled The Good, The Bad, and The Ugly that names the Mac by serial number and sanitizes all other identifiers, with a normalized timeline, a per-script deployment lens, limitations and read-only Zsh follow-up commands, then offers to redact the serial. Also runs second-pass re-audits that re-test prior findings and report a delta vs prior audit. Trigger with Mongoose, Good Bad Ugly, GBU audit, MDM policy audit, script deployment audit, system.log, jamf.log, install.log, reverse-domain script log, client-log bundle, sysdiagnose, re-audit, delta vs prior audit.
---
# Mongoose

Audit how MDM policies and custom script deployments behave on managed Macs, then write "The Good, The Bad, and The Ugly".

Primary inputs: `/var/log/system.log`, `/var/log/<mdm>.log` (Jamf Pro: `jamf.log`) and `/var/log/<rdnn>.log`, the organization's reverse-domain script log (for example `/var/log/org.churchofjesuschrist.log`). Optional: `install.log`, an MDM inventory JSON export, an Apple sysdiagnose, follow-up `Terminal Saved Output*.txt` transcripts and a prior Mongoose report.

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

1. **Inventory.** List every capture and member from contents, not names. Note gaps and truncation. Record the Mac's serial number and the source that states it.
2. **Hashes.** Record SHA-256 of every capture before analysis; re-check at the end.
3. **Time context.** Establish offsets and anchors before correlating anything.
4. **Symptom and script focus.** Locate the reported symptom, then assess each organization script through the script-deployment lens.
5. **Baseline health.** Run a broad health pass without letting background noise displace the focus.
6. **Timeline.** Build one material timeline, normalized to one offset, citing original `file:Lnn` and timestamp.
7. **GBU report.** Write the report; on a second pass, add the delta vs prior audit.
8. **Follow-up commands.** One round of grouped, read-only, paste-ready Zsh.
9. **Redaction prompt.** Once the findings are complete, ask whether to redact the serial number. If yes, replace it with `<serial>` throughout the report and confirm no copy remains.
10. **Offer post-chat-refine.** Only after the step 9 question is answered, end the closing reply with one line offering to fold this run's durable learnings back into the skill. Never ask both questions in one message. The offer goes in the reply, never in the report. Once declined, don't offer again this session.

## Load When

- Always: [Evidence Safety](references/evidence-safety.md) for citations, privacy, placeholders and follow-up command design.
- Steps 1-2: [Capture Layout](references/capture-layout.md) and [Inventory Commands](references/inventory-commands.md).
- Step 3, and any cross-source correlation: [Time Context](references/time-context.md).
- Step 4: [Script-Deployment Playbooks](references/script-deployment-playbooks.md).
- Before classifying any finding as Good, Bad or Ugly: [Interpretation Rules](references/interpretation-rules.md).
- Steps 7-9: [Report: The Good, The Bad, And The Ugly](references/report-gbu.md).
- A prior report or baseline capture is supplied: [Re-Audit Delta](references/re-audit-delta.md).
- A sysdiagnose is supplied: [Sysdiagnose Capture Layout](references/sysdiagnose/capture-layout.md), [Archive And Log Commands](references/sysdiagnose/archive-and-log-commands.md) and [Analysis Workflow](references/sysdiagnose/analysis-workflow.md).
- Enrollment or Setup Assistant handoff in a sysdiagnose: [ADE Handoffs](references/sysdiagnose/ade-handoffs.md).
- Privacy-proxy or OHTTP failure with a content filter, DNS proxy or VPN present: [Network Filters And OHTTP](references/sysdiagnose/network-filter-ohttp.md).
- The user accepts the Step 10 offer: [Post-Chat Refine](references/post-chat-refine.md).
- The user asks to slim or restructure the skill, or post-chat-refine leaves it over budget: [Binge And Purge](references/binge-and-purge.md).
