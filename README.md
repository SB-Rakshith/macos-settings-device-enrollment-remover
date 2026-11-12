# Temporary macOS enrollment-marker reset

Experimental workaround for a recurring “Enrol in Device Management” request. This does not release a computer from Apple Business or remove an installed MDM profile. macOS 27 badge removal has not been verified. Use only on a computer you own or are authorized to administer.

This tool changes four local marker files, saves their original contents or absence, verifies copied backup contents, and provides restore support. It does not create users, rename disks, change hosts entries, disable SIP, or reboot automatically. A local marker backup is not a backup of your personal files.

## Quick start from Recovery (no chat needed)

Open this public guide on your phone before restarting. Connect the Mac to Wi-Fi in Recovery. Unlock/mount the Data volume in Disk Utility as described below, then open Utilities → Terminal.

Download the script to Recovery's temporary storage and check its syntax:

```sh
curl -fL https://raw.githubusercontent.com/SB-Rakshith/macos-enrollment-marker-guide/main/enrollment-markers.sh -o /tmp/enrollment-markers.sh
bash -n /tmp/enrollment-markers.sh
```

Continue only if the download succeeds and the syntax check reports no errors. You can inspect it with `cat /tmp/enrollment-markers.sh` before running it. Then run:

```sh
bash /tmp/enrollment-markers.sh apply
```

This detects exactly one mounted Data volume, attempts to make it writable, backs up the four marker states, and attempts the reset. If it stops, follow the error guidance below rather than forcing it. Photograph the backup path and undo command. Only after success, restart:

```sh
reboot
```

**Undo later:** return to Recovery, unlock/mount Data, repeat the download and syntax-check commands, then run:

```sh
bash /tmp/enrollment-markers.sh restore
```

It restores the most recent complete marker backup. If automatic detection is ambiguous, specify the actual Data mount path as the next argument, for example `bash /tmp/enrollment-markers.sh restore "/Volumes/Data"`. This is not a guarantee of badge removal or continued suppression after an update.

## Before Recovery

Save the README on your phone or print it. Keep enrollment-markers.sh on your Mac alongside this README. Save important personal files somewhere else if they have no backup. This tool cannot protect against a failing disk.

Do not paste the whole script from a rich-text chat. Use the actual .sh file.

## 1. Start Recovery

Save your work and shut down.

- Apple silicon: hold Power until startup options appear, then choose Options → Continue.
- Intel: start while holding Command–R.

Choose an administrator and enter your existing password if requested. Do not select Erase or Reinstall.

## 2. Mount your Data volume

Open Disk Utility. Choose View → Show All Devices. Locate the internal APFS volume whose role is Data, often named Data or Macintosh HD - Data. Select it and click Mount; enter your login password if it is locked. Close Disk Utility and choose Utilities → Terminal.

If you cannot identify the volume, run:

```sh
diskutil apfs list
```

Look specifically for the volume marked `(Data)` belonging to the intended macOS installation. Use its identifier, for example disk3s5, in the following commands. **disk3s5 is an example, not a value to copy without checking.**

```sh
diskutil apfs unlockVolume disk3s5
diskutil mount disk3s5
```

If it is already unlocked, the unlock command is unnecessary. Enter passwords only into the local prompt. Do not erase, repair, or rename a volume to make these commands work.

## 3. Locate the saved script without a broad search

For the original Codex download location, run this narrow listing:

```sh
for f in /Volumes/*/Users/*/Documents/Codex/*/*/outputs/recovery-guide/enrollment-markers.sh; do
  [ ! -f "$f" ] || printf '%s\n' "$f"
done
```

If no path appears, the file is not available at that location. Restart normally and save the actual script into Documents, then return to Recovery. For a copy placed directly in Documents, list it with:

```sh
ls /Volumes/*/Users/*/Documents/enrollment-markers.sh
```

There is no need to search thousands of backup files.

## 4. Run the script

Use the full script path printed above, in quotes. Example only:

```sh
bash "/Volumes/Data/Users/YOUR_USERNAME/Documents/enrollment-markers.sh" apply
```

Replace the example with your actual path. With no volume argument the tool detects exactly one mounted installation with Users and enrollment Settings directories. If there are several candidates, specify the intended Data mount path:

```sh
bash "/actual/path/enrollment-markers.sh" apply "/Volumes/Data"
```

The tool prints its target and attempts to make that Data volume writable. If that fails, it stops before marker changes. Do not disable SIP to work around an error.

Backups are stored on that Data volume at:

```text
private/var/db/enrollment-marker-backups/backup-DATE-TIME-PID
```

Photograph the printed backup path and undo command. Avoid repeatedly applying this tool; each run creates a new backup of the state at that moment.

Only a message saying “Four marker changes completed” confirms the file operations completed. It does not confirm badge removal. If an operation fails, the tool attempts to restore the original four marker states and reports whether that worked. Preserve any backup if restore fails.

## 5. Restart and check

After success, use Apple menu → Restart, or type:

```sh
reboot
```

Open System Settings normally. If the entry remains, this workaround did not resolve it. Do not keep rerunning it or delete the entire ConfigurationProfiles directory. Organization release is the durable solution; updates can restore enrollment requests.

## Undo

Enter Recovery again and mount/unlock the same Data volume. Run the script with restore:

```sh
bash "/actual/path/enrollment-markers.sh" restore "/Volumes/Data"
```

This chooses the newest complete backup in the tool's backup directory. For a specific backup, use the exact printed command, or provide its path explicitly:

```sh
bash "/actual/path/enrollment-markers.sh" restore "/Volumes/Data" "/Volumes/Data/private/var/db/enrollment-marker-backups/backup-DATE-TIME-PID"
```

Use the same Data mount path as when applying. Restart normally after successful restore.

## What changed

- Back up `.cloudConfigHasActivationRecord` and `.cloudConfigRecordFound`, then remove those two local records.
- Back up any existing `.cloudConfigProfileInstalled` and `.cloudConfigRecordNotFound`, then create/touch those two markers.
- Preserve a record when an original file was absent so restore can recreate the original four-file state.

No enrollment records, credentials, serial numbers, or organization-specific URLs belong in this repository.

## Basis and validation

Marker approach reviewed against https://github.com/assafdori/bypass-mdm (commit fc91fec). Original repository: MIT license. This helper omits its account creation, setup bypass, and disk renaming. Compatibility reports: https://github.com/assafdori/bypass-mdm/issues/172 . Shell syntax checked; Recovery execution and macOS 27 badge suppression remain untested.
