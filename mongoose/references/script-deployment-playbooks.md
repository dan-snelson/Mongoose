# Script-Deployment Playbooks

Use after inventory and time context. Analysis here is read-only. Follow-up commands follow [Evidence Safety](evidence-safety.md).

## Process Exits Or Unexpected Kills

1. In a follow-up round, re-run the smallest representative read-only command and print its exit status.
2. Interpret exit status as evidence, not root cause. Status `137` indicates `SIGKILL` but does not identify who or what sent it.
3. Run the underlying executable directly when a package manager, wrapper, shell function or script is involved.
4. Compare direct execution with wrapped execution, including executable path, environment, parent process and child process.
5. Search endpoint-security and system sources in a tight time window for matching process IDs, paths, decisions, signals or code-signing events.

## Executable Or Environment Mismatch

1. Compare interactive-shell resolution with the environment created by the failing wrapper, MDM agent or package manager.
2. Use `type -a`, `command -v` and tool-specific environment output to identify every candidate executable.
3. Resolve symlinks and inspect link plus target. Do not assume the path shown by the shell is the binary ultimately executed.
4. Record version and architecture from the resolved executable.
5. Verify code-signing status when execution-control evidence makes it relevant.
6. Treat a different `PATH`, home-level dependency, architecture, signature or parent process as a lead until log evidence confirms causality.

## MDM Policy Or Provisioning Failure

1. Locate the policy, trigger, script, package or enrollment event in `<mdm>.log`. Jamf Pro: `Executing Policy <name>` and the trigger that started it, such as recurring check-in.
2. Correlate with `<rdnn>.log`, optional component logs, `install.log` and sysdiagnose evidence when available.
3. Separate MDM orchestration failures from failures inside the called script, installer, application or security product.
4. Check rotated system logs when the incident predates the current file.
5. Do not treat recurring historical warnings as causal without temporal and behavioral correlation.
6. Separate agent-to-server loss from MDM-channel loss. Jamf Pro `Could not connect to the JSS` lines cover only the `jamf` binary. MDM-delivered installs in `install.log` (for example Jamf App Installers) and `softwareupdated` DDM activity show whether commands and declarations still arrived.

## Per-Script Measurements

These feed the script-deployment lens in [Report: The Good, The Bad, And The Ugly](report-gbu.md).

Split `<rdnn>.log` into per-script blocks first: by log prefix, banner, PID or script name. Record how you split it, so others can reproduce every count. `<result>…</result>` lines are extension-attribute output: match the value to the inventory extension attribute to attribute them, and treat them as inventory-run markers. Normalize counts to rates (per hour of evidence, per boot or per policy run) before comparing windows.

| Measure | How to measure | Why it matters |
|---|---|---|
| Versioned log prefix | Share of blocks whose prefix or banner names a script version | Without a version, behavior cannot be tied to a release |
| Blocks with no version | Count of blocks with no version anywhere in the block | Same; also hides stale copies still running |
| Timestamp formats | Distinct timestamp shapes per script | Every extra format costs correlation effort and risks mis-ordering |
| Timestamp offset | Whether stamps carry an offset; offset compared with anchors | Offset-less stamps need anchoring before they can be correlated |
| Empty, blank and banner-only lines | Share of lines that are empty, whitespace only or decoration only, including spaced banners such as `# # #`; literal `\n` from unrendered escapes | Noise that inflates uploaded logs and hides real lines |
| Empty-variable bugs | Lines where a label is followed by nothing, such as `Version: ` or `user=""`; an empty JSON key `"":` from an unescaped `$` in a heredoc | A variable was unset when the script logged it |
| Exit codes and duration | Start, end and exit status per run; median and maximum duration | Slow or failing runs block later policies |
| Concurrency and interleaving | Overlapping runs; lines from two runs or PIDs interleaved; a script that hands off to a LaunchDaemon and returns, so the next policy in the same check-in overlaps it; a script that runs `jamf policy -event <trigger>` to install a missing dependency, starting a nested policy run while enrollment workflows are still running | Shared files, locks, logs and on-screen dialogs collide |
| Redundant runs and trigger use | Runs per policy per window, by trigger; repeats within minutes | Wasted work; recurring check-in used where an event trigger fits |
| Secrets as policy parameters | Parameter values visible in command lines, EPM audit records or the script's own log | Policy parameters are not a secret store |
| PII in uploaded logs | Usernames, real names, email addresses, serials, hardware UUIDs or IPs in `<rdnn>.log`, including webhook payloads logged verbatim; a real-name computer name repeats in every `<mdm>.log` host field | Collection uploads the log, so the data leaves the Mac |
| Endpoint-security and `install.log` noise | EPM audit records and `install.log` lines per run | Noise hides real security and install events |

Jamf Pro passes script parameters 4 through 11 as positional arguments. They can appear in process listings, EPM audit command lines and any log the script writes. Report that a secret was exposed and where; never print the value.

```zsh
log='logs/<bundle-directory>/<prefix>-com.example.it.log'
mdm_log='logs/<bundle-directory>/<prefix>-jamf.log'

# Line classes: total, empty, whitespace only, banner only.
awk '
  { total++ }
  /^$/ { empty++; next }
  /^[[:space:]]+$/ { blank++; next }
  /^[[:space:]]*([-=#*~_][[:space:]]*){3,}$/ { banner++ }
  END { printf "total %d\tempty %d\tblank %d\tbanner %d\n", total, empty, blank, banner }
' "$log"

# Rough timestamp-shape census: first 25 characters with digits masked.
cut -c1-25 "$log" | sed -E 's/[0-9]/9/g' | sort | uniq -c | sort -rn | head -n 20

# Empty-variable candidates: a label, assignment or JSON key with nothing in it.
rg -n -e ':[[:space:]]*$' -e '=[[:space:]]*$' -e '=""' -e "=''" -e '"":' "$log"

# Unrendered escapes: a literal backslash-n.
rg -n -F '\n' "$log"

# Jamf Pro: policy runs and trigger checks, by count.
rg -o 'Executing Policy .*' "$mdm_log" | sort | uniq -c | sort -rn
rg -o 'Checking for policies triggered by "[^"]*"' "$mdm_log" | sort | uniq -c | sort -rn
```

Adapt the patterns to the formats you find. Report the pattern used next to each count.
