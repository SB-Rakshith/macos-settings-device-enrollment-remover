#!/bin/bash
# Targeted, experimental enrollment-marker reset. Run only from Recovery.
set -eu
umask 077
names=(.cloudConfigHasActivationRecord .cloudConfigRecordFound .cloudConfigProfileInstalled .cloudConfigRecordNotFound)
fail() { echo "STOP: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail "Run this in Recovery Terminal, which runs as root."
mode=${1:-}
volume=${2:-}
if [ -z "$volume" ]; then
  candidates=()
  for candidate in /Volumes/*; do
    if [ -d "$candidate/private/var/db/ConfigurationProfiles/Settings" ] && [ -d "$candidate/Users" ]; then
      candidates+=("$candidate")
    fi
  done
  [ "${#candidates[@]}" = 1 ] || fail 'Could not identify exactly one mounted Data volume. Use Disk Utility to unlock/mount Data, or supply its /Volumes/... path explicitly.'
  volume=${candidates[0]}
fi
[ "$mode" = apply ] || [ "$mode" = restore ] || fail 'Usage: bash enrollment-markers.sh apply "/Volumes/DATA VOLUME" OR restore "/Volumes/DATA VOLUME" "/path/to/backup"'
case "$volume" in /Volumes/*) ;; *) fail 'Specify the mounted Data volume under /Volumes.' ;; esac
base="$volume/private/var"
settings="$base/db/ConfigurationProfiles/Settings"
[ -d "$settings" ] || fail "Enrollment Settings directory not found. Nothing changed."
[ -d "$volume/Users" ] || fail "Users directory absent. Nothing changed."
# Reject editing the currently running system, including aliases to its Data volume.
[ "$(stat -f %d "$base")" != "$(stat -f %d /private/var)" ] || fail 'This is the active macOS Data volume. Restart into Recovery first.'
echo "Target: $volume"
/sbin/mount -uw "$volume" || fail 'Cannot make the Data volume writable. No marker changes made. Do not disable SIP; restart normally if necessary.'
restore_files() {
  local backup="$1" name
  for name in "${names[@]}"; do
    if [ -f "$backup/$name" ]; then
      cp -p "$backup/$name" "$settings/$name" || return 1
    elif [ -f "$backup/absent-$name" ]; then
      rm -f "$settings/$name" || return 1
    else
      echo "Incomplete backup: $name" >&2; return 1
    fi
  done
}
if [ "$mode" = restore ]; then
  backup=${3:-}
  if [ -z "$backup" ]; then
    for candidate in "$base/db/enrollment-marker-backups"/backup-*; do
      [ ! -f "$candidate/backup-complete" ] || backup="$candidate"
    done
  fi
  [ -f "$backup/backup-complete" ] || fail 'Not a complete marker backup.'
  [ "$(cat "$backup/settings-path")" = "$settings" ] || fail 'Backup volume path differs. Use the same mounted volume name as during apply.'
  restore_files "$backup" || fail 'Restore failed; preserve the backup and report the error.'
  echo 'Original four marker states restored. Restart normally.'
  exit 0
fi
mkdir -p "$base/db/enrollment-marker-backups"
chmod 700 "$base/db/enrollment-marker-backups"
backup="$base/db/enrollment-marker-backups/backup-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -m 700 "$backup"
printf '%s\n' "$settings" > "$backup/settings-path"
for name in "${names[@]}"; do
  [ ! -L "$settings/$name" ] || fail "Unexpected symlink: $name. Nothing changed."
  if [ -e "$settings/$name" ]; then
    [ -f "$settings/$name" ] || fail "Unexpected file type: $name. Nothing changed."
    cp -p "$settings/$name" "$backup/$name"
    cmp -s "$settings/$name" "$backup/$name" || fail "Backup verification failed. No marker changes made."
  else
    touch "$backup/absent-$name"
  fi
done
touch "$backup/backup-complete"
echo "Backup: $backup"
if rm -f "$settings/.cloudConfigHasActivationRecord" "$settings/.cloudConfigRecordFound" &&
   touch "$settings/.cloudConfigProfileInstalled" "$settings/.cloudConfigRecordNotFound"; then
  echo 'Four marker changes completed. This does not prove enrollment suppression succeeded.'
  printf 'Undo from Recovery:\nbash "%s" restore "%s" "%s"\n' "$0" "$volume" "$backup"
  echo 'Restart normally and check Settings. No account, hosts, disk name, or SIP changes were made.'
else
  echo 'A change failed. Attempting to restore the original marker files.' >&2
  restore_files "$backup" || fail "Automatic restore failed. Keep backup: $backup"
  fail 'Original marker states restored. Report the error; do not disable SIP.'
fi
