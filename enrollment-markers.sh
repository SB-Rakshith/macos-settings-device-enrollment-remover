#!/bin/bash
# macOS Enrollment Request Helper. Bash 3.2 compatible; run from Recovery.
set -eu
umask 077
VERSION=1.1.0
names=(.cloudConfigHasActivationRecord .cloudConfigRecordFound .cloudConfigProfileInstalled .cloudConfigRecordNotFound)
fail() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
step() { printf '\n[%s] %s\n' "$1" "$2"; }
usage() {
  printf 'macOS Enrollment Request Helper %s\n' "$VERSION"
  cat <<'EOF'
Usage: bash enrollment-markers.sh [status|apply|restore] ["/Volumes/Data"] ["backup-path"]
  status   Inspect markers without changing the volume (default).
  apply    Preview, confirm, back up, verify, then change four markers.
  restore  Select and validate a backup, confirm, then restore its four states.
Run apply/restore from macOS Recovery. Nothing reboots automatically.
EOF
}
confirm() {
  local answer
  [ -t 0 ] || fail 'An interactive Terminal is required for changes.'
  printf '\nType %s to continue: ' "$1"
  IFS= read -r answer || fail 'Confirmation cancelled.'
  [ "$answer" = "$1" ] || fail 'Cancelled. No marker changes made.'
}
find_comparator() {
  local candidate
  CMP=
  if command -v cmp >/dev/null 2>&1; then
    candidate=$(command -v cmp)
    if "$candidate" -s /dev/null /dev/null; then CMP=$candidate; return; fi
  fi
  for candidate in /Volumes/*/usr/bin/cmp; do
    [ -x "$candidate" ] || continue
    if "$candidate" -s /dev/null /dev/null 2>/dev/null; then CMP=$candidate; return; fi
  done
  fail 'No working cmp found. Mount the Macintosh HD System volume in Disk Utility and retry. Backup verification is required.'
}
validate_states() {
  local directory="$1" name
  for name in "${names[@]}"; do
    [ ! -L "$directory/$name" ] || fail "Unexpected symlink: $directory/$name"
    if [ -e "$directory/$name" ]; then
      [ -f "$directory/$name" ] || fail "Unexpected file type: $directory/$name"
    fi
  done
}
validate_backup() {
  local backup="$1" name
  [ -d "$backup" ] && [ ! -L "$backup" ] || fail 'Invalid backup directory.'
  for name in backup-complete settings-path volume-uuid; do
    [ -f "$backup/$name" ] && [ ! -L "$backup/$name" ] || fail "Incomplete backup: $name"
  done
  [ "$(cat "$backup/volume-uuid")" = "$volume_uuid" ] || fail 'Backup belongs to another Data volume.'
  validate_states "$backup"
  for name in "${names[@]}"; do
    [ ! -L "$backup/absent-$name" ] || fail 'Unexpected symlink in backup.'
    if [ -f "$backup/$name" ]; then
      [ ! -e "$backup/absent-$name" ] || fail "Ambiguous backup: $name"
    else
      [ -f "$backup/absent-$name" ] || fail "Incomplete backup: $name"
    fi
  done
}
backup_states() {
  local destination="$1" name
  mkdir -m 700 "$destination"
  printf '%s\n' "$settings" > "$destination/settings-path"
  printf '%s\n' "$volume_uuid" > "$destination/volume-uuid"
  for name in "${names[@]}"; do
    if [ -f "$settings/$name" ]; then
      cp -p "$settings/$name" "$destination/$name"
      "$CMP" -s "$settings/$name" "$destination/$name" || fail 'Backup verification failed. No marker changes made.'
    else
      touch "$destination/absent-$name"
    fi
  done
  touch "$destination/backup-complete"
}
restore_states() {
  local backup="$1" name
  for name in "${names[@]}"; do
    if [ -f "$backup/$name" ]; then
      cp -p "$backup/$name" "$settings/$name" || return 1
      "$CMP" -s "$backup/$name" "$settings/$name" || return 1
    else
      rm -f "$settings/$name" || return 1
      [ ! -e "$settings/$name" ] || return 1
    fi
  done
}
choose_volume() {
  local candidate choice i
  candidates=()
  for candidate in /Volumes/*; do
    if [ -d "$candidate/Users" ] && [ -d "$candidate/private/var/db/ConfigurationProfiles/Settings" ]; then
      candidates+=("$candidate")
    fi
  done
  [ "${#candidates[@]}" -gt 0 ] || fail 'No mounted Data volume found. Unlock and mount Data using Disk Utility, then retry.'
  if [ "${#candidates[@]}" = 1 ]; then volume=${candidates[0]}; return; fi
  printf '\nMounted Data volumes:\n'
  i=0
  for candidate in "${candidates[@]}"; do i=$((i + 1)); printf '  %s) %s\n' "$i" "$candidate"; done
  printf 'Select a volume number: '
  IFS= read -r choice || fail 'Selection cancelled.'
  case "$choice" in ''|*[!0-9]*) fail 'Invalid selection.' ;; esac
  [ "${#choice}" -le 3 ] || fail 'Invalid selection.'
  choice=$((10#$choice))
  [ "$choice" -ge 1 ] && [ "$choice" -le "${#candidates[@]}" ] || fail 'Invalid selection.'
  volume=${candidates[$((choice - 1))]}
}
main() {
  local mode="${1:-status}" volume="${2:-}" backup="${3:-}" tool name candidate root count answer
  case "$mode" in -h|--help|help) usage; return ;; status|apply|restore) ;; *) usage; fail 'Unknown mode.' ;; esac
  [ "$#" -le 3 ] || fail 'Too many arguments.'
  [ "$(uname -s)" = Darwin ] || fail 'This helper requires macOS.'
  step '1/5' 'Checking environment and tools'
  for tool in stat diskutil awk cat; do command -v "$tool" >/dev/null 2>&1 || fail "Missing tool: $tool"; done
  [ -n "$volume" ] || choose_volume
  case "$volume" in /Volumes/*) ;; *) fail 'Use a mounted Data volume path under /Volumes/ (plural).' ;; esac
  volume=$(cd "$volume" && pwd -P) || fail 'Volume unavailable.'
  case "$volume" in /Volumes/*) ;; *) fail 'Volume resolves outside /Volumes.' ;; esac
  settings="$volume/private/var/db/ConfigurationProfiles/Settings"
  [ -d "$settings" ] && [ -d "$volume/Users" ] || fail 'Selected volume has no Users or enrollment Settings directory.'
  validate_states "$settings"
  step '2/5' "Target: $volume"
  printf 'Marker states:\n'
  for name in "${names[@]}"; do
    if [ -f "$settings/$name" ]; then printf '  present  %s\n' "$name"; else printf '  absent   %s\n' "$name"; fi
  done
  [ "$mode" != status ] || { printf '\nRead-only inspection complete. No changes made.\n'; return; }
  [ "$(id -u)" = 0 ] || fail 'Run from Recovery Terminal as root.'
  [ -d /System/Installation/CDIS ] || fail 'Recovery environment not detected. Restart into Recovery.'
  [ "$(stat -f %d "$volume/private/var")" != "$(stat -f %d /private/var)" ] || fail 'Refusing to change the running macOS Data volume.'
  for tool in cp mkdir chmod touch rm date; do command -v "$tool" >/dev/null 2>&1 || fail "Missing tool: $tool"; done
  find_comparator
  printf 'Backup verifier: %s\n' "$CMP"
  volume_uuid=$(diskutil info "$volume" | awk '/Volume UUID:/ {print $NF}')
  [ -n "$volume_uuid" ] || fail 'Cannot read the Data volume UUID.'
  root="$volume/private/var/db/enrollment-marker-backups"
  [ ! -L "$root" ] || fail 'Backup directory is a symlink.'
  if [ "$mode" = restore ]; then
    if [ -z "$backup" ]; then
      count=0
      for candidate in "$root"/backup-*; do
        [ -f "$candidate/backup-complete" ] || continue
        count=$((count + 1)); backup=$candidate
        printf 'Available backup: %s\n' "$candidate"
      done
      [ "$count" = 1 ] || fail 'Supply one exact backup path. Zero or multiple complete backups found; none selected automatically.'
    fi
    validate_backup "$backup"
    printf '\nRestore the four saved marker states from:\n%s\n' "$backup"
    confirm RESTORE
  else
    for candidate in "$root"/backup-*; do
      [ ! -f "$candidate/backup-complete" ] || fail "A complete backup already exists: $candidate. Do not apply repeatedly; use status or restore."
    done
    printf '\nThis removes two local activation/record markers and creates two\nprofile-installed/record-not-found markers. It does not release organization\nenrollment or remove an installed MDM profile. The request may return.\n'
    confirm APPLY
  fi
  step '3/5' 'Making the selected Data volume writable'
  /sbin/mount -uw "$volume" || fail 'Cannot make Data writable. No marker changes made. Do not disable SIP.'
  validate_states "$settings"
  if [ "$mode" = restore ]; then
    # Preserve the current state too, before attempting a restore.
    mkdir -p "$root"; chmod 700 "$root"
    candidate="$root/pre-restore-$(date +%Y%m%d-%H%M%S)-$$"
    backup_states "$candidate"
    printf 'State before restore saved at: %s\n' "$candidate"
    step '4/5' 'Restoring and verifying original marker states'
    restore_states "$backup" || fail "Restore failed. Preserve backups in $root and report the error."
  else
    mkdir -p "$root"; chmod 700 "$root"
    backup="$root/backup-$(date +%Y%m%d-%H%M%S)-$$"
    step '4/5' 'Backing up and verifying all four marker states'
    backup_states "$backup"
    printf 'Verified backup: %s\n' "$backup"
    # Roll back on an error or terminal interrupt after marker changes begin.
    trap 'trap - EXIT HUP INT TERM; printf "\nInterrupted or failed; restoring backup.\n" >&2; restore_states "$backup" || printf "RESTORE FAILED. Keep backup: %s\n" "$backup" >&2; exit 1' EXIT
    trap 'exit 1' HUP INT TERM
    rm -f "$settings/.cloudConfigHasActivationRecord" "$settings/.cloudConfigRecordFound"
    touch "$settings/.cloudConfigProfileInstalled" "$settings/.cloudConfigRecordNotFound"
    if [ -e "$settings/.cloudConfigHasActivationRecord" ] || [ -e "$settings/.cloudConfigRecordFound" ] ||
       [ ! -f "$settings/.cloudConfigProfileInstalled" ] || [ ! -f "$settings/.cloudConfigRecordNotFound" ]; then
      fail 'Marker verification failed; attempting rollback.'
    fi
    trap - EXIT HUP INT TERM
  fi
  step '5/5' 'File operations completed and verified'
  printf '\nKeep a photo of this backup path:\n%s\n' "$backup"
  printf '\nRestore from Recovery after downloading the helper again:\n'
  printf 'bash /tmp/enrollment-markers.sh restore %q %q\n' "$volume" "$backup"
  printf '\nRestart manually, then check System Settings.\nFile verification does not prove the Settings request has cleared.\n'
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
