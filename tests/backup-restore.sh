#!/bin/bash
# Isolated tests. Never invokes main, mount, or actual system settings.
set -eu
cd "$(dirname "$0")/.."
source ./enrollment-markers.sh
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
settings="$fixture/settings"
mkdir "$settings"
volume_uuid=fixture-volume
CMP=$(command -v cmp)
printf 'original\000bytes\n' > "$settings/${names[0]}"
printf 'installed\n' > "$settings/${names[2]}"
backup_states "$fixture/backup"
validate_backup "$fixture/backup"
printf 'changed\n' > "$settings/${names[0]}"
touch "$settings/${names[1]}" "$settings/${names[3]}"
rm "$settings/${names[2]}"
restore_states "$fixture/backup"
"$CMP" -s "$settings/${names[0]}" "$fixture/backup/${names[0]}"
"$CMP" -s "$settings/${names[2]}" "$fixture/backup/${names[2]}"
[ ! -e "$settings/${names[1]}" ] && [ ! -e "$settings/${names[3]}" ]
printf 'PASS: restore preserves binary contents and original absence\n'
# A full validation must reject corrupt/incomplete and foreign backups.
rm "$fixture/backup/absent-${names[1]}"
if (validate_backup "$fixture/backup") >/dev/null 2>&1; then exit 1; fi
touch "$fixture/backup/absent-${names[1]}"
if (volume_uuid=other; validate_backup "$fixture/backup") >/dev/null 2>&1; then exit 1; fi
touch "$fixture/backup/absent-${names[0]}"
if (validate_backup "$fixture/backup") >/dev/null 2>&1; then exit 1; fi
rm "$fixture/backup/absent-${names[0]}"
ln -s "$fixture/settings/${names[0]}" "$settings/${names[1]}"
if (validate_states "$settings") >/dev/null 2>&1; then exit 1; fi
printf 'PASS: incomplete, foreign, ambiguous, and symlink states rejected\n'
rm "$settings/${names[1]}"
if (CMP=/bin/false; backup_states "$fixture/bad-backup") >/dev/null 2>&1; then exit 1; fi
[ ! -e "$fixture/bad-backup/backup-complete" ]
printf 'PASS: failed verification cannot produce a complete backup\n'
bash ./enrollment-markers.sh --help >/dev/null
printf 'PASS: help works without changing system settings\n'
for mask in {0..15}; do
  settings="$fixture/states-$mask"
  mkdir "$settings"
  for index in {0..3}; do
    if [ $((mask & (1 << index))) -ne 0 ]; then
      printf 'state-%s\000\n' "$index" > "$settings/${names[$index]}"
    fi
  done
  backup_states "$fixture/backup-$mask"
  validate_backup "$fixture/backup-$mask"
  for name in "${names[@]}"; do printf changed > "$settings/$name"; done
  restore_states "$fixture/backup-$mask"
  for index in {0..3}; do
    if [ $((mask & (1 << index))) -ne 0 ]; then
      "$CMP" -s "$settings/${names[$index]}" "$fixture/backup-$mask/${names[$index]}"
    else
      [ ! -e "$settings/${names[$index]}" ] || exit 1
    fi
  done
done
printf 'PASS: all 16 marker presence/absence combinations round-trip\n'
