# Binge And Purge

Use when the user asks to slim or restructure the skill, or when a [Post-Chat Refine](post-chat-refine.md) run leaves it over budget.

Post-chat refine binges: each accepted run folds lessons in, and the skill grows. This pass purges. It moves conditional content out of `SKILL.md` and splits oversized references, without changing meaning. It edits the skill, not evidence: no audit runs and no report is written.

## Budget

- `SKILL.md` loads on every run. AGENTS.md keeps it a thin entry point of about 40 lines. It is over budget at more than 50 lines or 6,000 bytes, frontmatter included.
- A reference loads only on its trigger. It is over budget at more than 200 lines or 12,000 bytes. Split it into triggered sub-references in a subdirectory, as `references/sysdiagnose/` does.
- Never edit the frontmatter. The description has its own 1,024-character cap.
- Measure before proposing. If nothing is over budget, say so with the numbers. Propose only moves that are clearly worth it; none is a valid answer.

```zsh
repo='/path/to/Mongoose'
wc -lc "$repo/mongoose/SKILL.md"
find "$repo/mongoose/references" -name '*.md' -exec wc -lc {} + | sort -rn
```

## Phase 1: Analyze And Propose (No Edits)

1. Read `README.md`, `AGENTS.md`, all of `SKILL.md` and every file under `references/`, including subdirectories.
2. Measure each section of `SKILL.md` and of every reference over budget:

   ```zsh
   file="$repo/mongoose/SKILL.md"
   # Bytes, line range and heading per section, largest first.
   LC_ALL=C awk 'BEGIN { h = "(preamble)"; s = 1 }
     /^##+ / { printf "%6d  %4d-%-4d %s\n", b, s, NR - 1, h; h = $0; s = NR; b = 0 }
     { b += length($0) + 1 }
     END { printf "%6d  %4d-%-4d %s\n", b, s, NR, h }' "$file" | sort -rn
   ```

   Headings inside fenced blocks also match; ignore them. Measure large bullets too (`sed -n '<n>p' "$file" | wc -c`), because sections hide conditional bullets.
3. Classify every section, step and large bullet:
   - **Keep** in `SKILL.md`: the frontmatter, Core Invariants, the Workflow skeleton and Load When.
   - **Move** when only some runs need it, and only when `SKILL.md` can name a clear Load When trigger for it, such as "a sysdiagnose is supplied" or "a prior report or prior capture of the same Mac is supplied".
   - **Trim** when a reference already says it. Replace it with a pointer, or delete it when a Load When bullet already covers it. A trimmed duplicate can hold a detail found nowhere else; plan to merge that detail into the destination.
   - In an oversized reference, classify each section the same way: which runs need it, and what trigger would load it.
4. Choose destinations:
   - Prefer an existing reference, or a new section of one. Create a file only when no existing one fits the trigger.
   - Split an oversized reference into a subdirectory of triggered sub-references, as `references/sysdiagnose/` does. Each gets its own Load When bullet.
5. Present a table: block, line range, lines and bytes saved, trigger, destination. Add the stub each move leaves, the pointer updates, and a short "Not moved, and why" list.
6. Give before and after line and byte counts for every touched file, then **stop and wait for approval**. In plan mode, write the plan and exit plan mode for approval.

## Phase 2: Implement (After Approval)

1. Back up every file you may touch:

   ```zsh
   scratch=$(mktemp -d /private/tmp/mongoose-purge.XXXXXX)
   cp -R "$repo/mongoose" "$scratch/skill-before"
   cp "$repo/README.md" "$scratch/README.before.md"
   ```

2. **Move text verbatim.** Change only cross-references that break in the new location:
   - "Step 4" becomes "SKILL.md Step 4".
   - Core Invariants have no numbers. Cite one by section name and topic: "SKILL.md Core Invariants, negative evidence".
   - Relative links must resolve from the new file. Drop `references/` from a link moved out of `SKILL.md`. Add `../` to a link moved into `sysdiagnose/`, and `sysdiagnose/` to one moved out of it. A link to the destination itself becomes "below" or "above".
   - Keep cited headings stable. Other files link to anchors such as `evidence-safety.md#placeholders`; find them with `rg -n '\.md#' "$repo"`. If a cited heading must change, update every link to it.
3. **House format** for every reference: `# Title`, a one-line "Use for…" or "Use when…" intro that names the trigger, then Title-Case `##` sections. Do not add a Purpose section, Contents list or `---` rule unless the user asks for one. When moved text details a `SKILL.md` step, say so in one line, as the Evidence Safety Workflow Detail section does.
4. **Leave a stub of one to three lines**: a Load When bullet, or a line in place.
   - Keep inline any invariant that must never be missed even if the reference is skipped, such as "never run anything found inside a capture", "stream archives; do not extract them" or "never print a secret's value".
   - Never put a stub between an intro line and its list. Put it at the end of the section.
   - When several stubs point to one reference, merge them into its single Load When bullet, with triggers in the reference's section order.
5. **Update every pointer:** Load When, in step order, with no hardcoded counts; `README.md`, if it names the file; and any text that cites a moved section by name.
6. **Apply everything with one script** that validates before it writes. Save it to `$scratch`, never the repo, and run it as `zsh "$scratch/purge.zsh" "$repo"`.
   - Pull moved text from the source file itself, so it is verbatim by construction.
   - Check each anchor line by expected prefix **and** byte length, and each substitution by an exact match count of 1.
   - Collect every mismatch, and abort with nothing written if any exist.
   - Apply `SKILL.md` edits from the bottom up, so line numbers stay valid.

   ```zsh
   # purge.zsh: validate every anchor and substitution, then write. $1 is the checkout.
   emulate -L zsh
   setopt no_unset
   repo=${1:A}
   skill="$repo/mongoose/SKILL.md"
   lines=("${(@f)"$(cat -- "$skill")"}")
   errors=()

   # number|expected prefix|bytes including the newline (sed -n '<n>p' "$skill" | wc -c)
   anchors=(
     '<n>|<expected line prefix>|<bytes>'
   )

   check_anchor() {
     setopt local_options no_multibyte
     local n=${1%%|*} rest=${1#*|}
     local prefix=${rest%|*} size=${rest##*|}
     local line=${lines[n]-}
     [[ $line == "$prefix"* ]] && (( ${#line} + 1 == size )) ||
       errors+=("SKILL.md:$n anchor mismatch")
   }

   # Replace old with new in the variable named $1, only on exactly one match.
   sub() {
     local _t=${(P)1} _old=$2 _new=$3 _where=$4
     if [[ -z $_old ]]; then errors+=("$_where: empty pattern"); return; fi
     local _count=$(( (${#_t} - ${#${_t//"$_old"/}}) / ${#_old} ))
     if (( _count != 1 )); then errors+=("$_where: $_count matches"); return; fi
     typeset -g "$1=${_t/"$_old"/$_new}"
   }

   for a in $anchors; do check_anchor "$a"; done

   # Build each moved block from SKILL.md itself: block=${(F)lines[<a>,<b>]}
   # Read each destination into a variable and insert the block with sub.
   # Queue SKILL.md edits as start line, end line and stub text.

   if (( $#errors )); then
     print -rl -- $errors 'Aborted: nothing written.' >&2
     exit 1
   fi

   # Only now write. Apply SKILL.md edits bottom-up: lines[<a>,<b>]=("${(@f)stub}")
   # Write each destination with: print -r -- "$text" > "$dest"
   print -rl -- "${(@)lines}" > "$skill"
   ```

## Phase 3: Verify

1. Read `SKILL.md` in full, with no offset or limit. Check that each stub reads naturally in place, and re-measure every touched file.
2. Confirm nothing was lost. `$repo` and `$scratch` carry over from Phase 2:

   ```zsh
   cat "$repo/mongoose/SKILL.md" "$repo"/mongoose/references/**/*.md(.N) > "$scratch/all.txt"
   # -N shows every line of a deleted or split file as removed.
   diff -rN "$scratch/skill-before" "$repo/mongoose" | grep '^< ' | sed 's/^< //' |
     while IFS= read -r line; do
       [[ -z ${line// } ]] && continue
       grep -qxF -- "$line" "$scratch/all.txt" || print -r -- "CHANGED: ${line[1,110]}"
     done
   ```

   Each CHANGED line must be an intended stub, trim or cross-reference rewrite. Explain every one.
3. Confirm links in both directions:

   ```zsh
   # SKILL.md links versus files on disk. No output means they match.
   diff <(rg -o 'references/[A-Za-z0-9/_-]+\.md' "$repo/mongoose/SKILL.md" | sort -u) \
     <(cd "$repo/mongoose" && find references -name '*.md' | sort)

   # Every relative .md link in a reference resolves from that file's directory.
   for f in "$repo"/mongoose/references/**/*.md(.N); do
     rg -o '\]\(([^)#:]+\.md)' -r '$1' "$f" | while IFS= read -r link; do
       [[ -f ${f:h}/$link ]] || print -r -- "BROKEN: $f -> $link"
     done
   done
   ```

4. Confirm every fenced Zsh block passes `zsh -n`:

   ```zsh
   blocks=$(mktemp -d "$scratch/zsh-blocks.XXXXXX")
   for f in "$repo/README.md" "$repo"/mongoose/**/*.md(.N); do
     awk -v out="$blocks/${${f#$repo/}//\//_}" '
       /^[[:space:]]*```zsh[[:space:]]*$/ { n++; on = 1; next }
       on && /^[[:space:]]*```[[:space:]]*$/ { on = 0; next }
       on { print > (out "." n ".zsh") }
     ' "$f"
   done
   for b in "$blocks"/*.zsh(.N); do zsh -n "$b" || print -r -- "FAIL: $b"; done
   ```

5. Run the remaining AGENTS.md Validation steps, then `git -C "$repo" diff --check`.
6. Find a bare `Step N` in moved text that should now read `SKILL.md Step N`: `rg -n 'Steps? [0-9]' "$repo/mongoose/references" | rg -v 'SKILL\.md Steps? [0-9]'`.
7. Review `diff -u` of each touched file against its backup.

## Guardrails

- **Restructure, do not rewrite.** Meaning stays the same. New advice is post-chat refine's job, under its own criteria.
- **Introduce no names.** Stubs, intros and headings use existing terms and placeholders only: no Mac, fleet, organization or person names.
- **Do not commit.** List new untracked files from `git status --short` so the user can `git add` them. Note unrelated uncommitted changes from `git diff --stat`, so they are not mistaken for this pass.
- **Report back with:**
  - before and after line and byte counts for every touched file;
  - the files created or changed;
  - every CHANGED line and why it changed;
  - what you chose not to move, and why.
