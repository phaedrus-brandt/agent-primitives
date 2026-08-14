#!/bin/sh
# check-skills — validate skills/*/SKILL.md before install.sh links them.
# Exits 1 on any error; warnings are non-fatal (printed, counted, reported).
set -eu

REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SKILLS_DIR="$REPO/skills"

errors=0
warnings=0
count=0
seen_names="
"

for d in "$SKILLS_DIR"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  file="${d}SKILL.md"

  # test -f follows symlinks, so a symlinked skill dir (e.g. skills/ranger)
  # is checked through to its target.
  if [ ! -f "$file" ]; then
    echo "check-skills: $name: missing SKILL.md"
    errors=$((errors + 1))
    continue
  fi
  count=$((count + 1))

  first_line="$(sed -n '1p' "$file")"
  if [ "$first_line" != "---" ]; then
    echo "check-skills: $name: frontmatter does not open with --- on line 1"
    errors=$((errors + 1))
    continue
  fi

  close_line="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")"
  if [ -z "$close_line" ]; then
    echo "check-skills: $name: frontmatter is not closed with ---"
    errors=$((errors + 1))
    continue
  fi

  frontmatter="$(sed -n "2,$((close_line - 1))p" "$file")"

  name_val="$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -n1)"
  name_val="$(printf '%s' "$name_val" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")"
  if [ -z "$name_val" ]; then
    echo "check-skills: $name: missing name: in frontmatter"
    errors=$((errors + 1))
  else
    if [ "$name_val" != "$name" ]; then
      echo "check-skills: $name: name: '$name_val' does not match directory name"
      errors=$((errors + 1))
    fi
    if printf '%s' "$seen_names" | grep -qxF "$name_val"; then
      echo "check-skills: $name: duplicate name: '$name_val' also used by another skill"
      errors=$((errors + 1))
    else
      seen_names="${seen_names}${name_val}
"
    fi
  fi

  desc_val="$(printf '%s\n' "$frontmatter" | sed -n 's/^description:[[:space:]]*//p' | head -n1)"
  desc_val="$(printf '%s' "$desc_val" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")"
  if [ -z "$desc_val" ]; then
    echo "check-skills: $name: missing or empty description:"
    errors=$((errors + 1))
  fi

  lines="$(wc -l < "$file" | tr -d ' ')"
  if [ "$lines" -gt 250 ]; then
    echo "check-skills: $name: SKILL.md is $lines lines (warn: exceeds 250)"
    warnings=$((warnings + 1))
  fi
done

if [ "$errors" -gt 0 ]; then
  echo "check-skills: $count skills checked, $errors errors, $warnings warnings"
  exit 1
fi
echo "check-skills: $count skills OK ($warnings warnings)"
