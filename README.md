# macOS Enrollment Request Helper

**For the recurring “Enrol in Device Management” request in Mac System Settings.**

A guided Recovery Terminal helper that saves the original state of four local enrollment marker files, changes those markers, and provides a restore command.

**Reported working on macOS 27:** on 12 November 2026, the repository owner reported that the Settings request disappeared after running the original marker reset and restarting. This is one user report; the revised guided helper has automated checks but still needs a real Recovery run. The exact macOS build was not recorded.

> Use on a Mac you own or are authorized to administer. This changes local markers; it does not release the Mac from Apple Business Manager/Apple School Manager or remove an installed MDM profile. Results can vary, and an update or enrollment check can bring the request back. Organization release is the durable solution.

## Is this the issue you have?

This guide is for an **enrollment request inside System Settings on a Mac you can already log into**. It is not a guide for Activation Lock, a Remote Management screen blocking Setup Assistant, or removal of an installed management profile.

An issue screenshot will be added when supplied by the owner. There is no need to upload a serial number, password, recovery key, organization identifier, or email address.

## What will it do?

| Step | Behavior |
| --- | --- |
| Inspect | Show the selected Data volume and which of the four markers exist. |
| Check | Check Recovery, required commands, and a working backup comparison tool. |
| Confirm | Wait for you to type `APPLY` before making changes. |
| Back up | Save each original file or a record of its absence, then verify copied contents. |
| Change | Remove two markers and create/touch two others, listed below. |
| Verify | Check the resulting marker states; attempt rollback if the operation fails or is interrupted. |
| Finish | Print the backup path and exact restore command. Restart is manual. |

It does not erase a disk, rename volumes, create accounts, change hosts entries, disable SIP, or reboot automatically. The marker backup is **not a backup of personal files**. Back up important files separately before starting.

## Start here

Keep this page open on your phone. Save your work, connect your Mac to power, and enter Recovery:

- **Apple silicon:** shut down, hold Power until startup options appear, then choose **Options → Continue**.
- **Intel:** restart while holding **Command–R**.

Choose an administrator and enter your password if requested. Connect Recovery to Wi-Fi. Do not select Erase or Reinstall.

### 1. Unlock and mount Data

In **Disk Utility → View → Show All Devices**, find the internal volume with the **Data** role. Select it and click **Mount**, entering your Mac login password if prompted. Also mount the corresponding **Macintosh HD System volume** if available: Recovery may need its `cmp` command for backup verification.

Close Disk Utility, then open **Utilities → Terminal**.

If you cannot identify Data, use this read-only command:

```sh
diskutil apfs list
```

Find the entry marked `(Data)` for the intended installation. Disk identifiers can change after a restart. Never copy another person's `disk3s1` or any example identifier without checking yours.

### 2. Download and check the helper

Download the file first; do not pipe a download directly into Bash:

```sh
curl -fL https://raw.githubusercontent.com/SB-Rakshith/macos-enrollment-marker-guide/main/enrollment-markers.sh -o /tmp/enrollment-markers.sh
```

Continue only if the download succeeds. Then check syntax:

```sh
bash -n /tmp/enrollment-markers.sh
```

No output means the syntax check passed. It does not prove compatibility or authenticity. You can inspect the downloaded script with `cat /tmp/enrollment-markers.sh`. The URL above follows `main`; for a reproducible download, replace `main` with a full reviewed commit SHA from GitHub's commit history. No versioned release is claimed here.

### 3. Preview without changes

```sh
bash /tmp/enrollment-markers.sh status
```

The helper detects mounted Data volumes. If more than one is found, it asks you to choose. Check that the displayed target belongs to the installation you intend to change.

You can supply an exact mount path if needed, for example:

```sh
bash /tmp/enrollment-markers.sh status "/Volumes/Data"
```

`/Volumes/Data` is an example: use the path actually shown for your Mac.

### 4. Apply once

```sh
bash /tmp/enrollment-markers.sh apply
```

Read the target and explanation. Type `APPLY` only if they are correct. The helper makes Data writable, backs up the four markers, verifies the backup, changes the markers, and verifies the resulting file states.

Expected progress:

```text
[1/5] Checking environment and tools
[2/5] Target: /Volumes/Data
...
Type APPLY to continue:
[3/5] Making the selected Data volume writable
[4/5] Backing up and verifying all four marker states
Verified backup: ...
[5/5] File operations completed and verified
```

**Photograph the backup path and restore command.** If a `STOP` message appears, read it and stop; do not disable SIP or delete the entire ConfigurationProfiles directory. Do not repeatedly apply the helper.

### 5. Restart and check Settings

After all five stages succeed, choose **Apple menu → Restart**, or run:

```sh
reboot
```

Log in and open **System Settings**. Successful file operations do not guarantee the enrollment request disappears. If it remains, do not keep reapplying; restore the original state and contact the organization or seller about enrollment release.

## Undo the change

Return to Recovery, unlock/mount the same Data volume, and download/check the helper again using step 2. Files in Recovery's `/tmp` do not survive a restart.

Use the **exact restore command printed during apply**. Alternatively:

```sh
bash /tmp/enrollment-markers.sh restore
```

One complete backup is selected automatically. If multiple backups exist, the helper lists them and requires an explicit path instead of guessing. It validates the backup's volume UUID and all four saved states before changes, asks you to type `RESTORE`, and saves the current state before restoring.

The older helper's backups do not contain a volume UUID. This version intentionally refuses those backups; retain the original helper and its printed restore instructions for an older backup.

## Troubleshooting

| Message or symptom | Next step |
| --- | --- |
| No mounted Data volume | Unlock and mount the Data role in Disk Utility. |
| Wrong volume or missing Users/Settings | Stop and select the correct installation; do not create missing system directories. |
| No working `cmp` | Mount the matching Macintosh HD System volume. The helper tests its comparator automatically. It never skips backup verification. |
| Download fails | Check Wi-Fi and the typed URL. Do not use `curl -k` or run a partial download. |
| Recovery not detected | Run changes from Apple Recovery, not normal macOS or an arbitrary root shell. |
| Cannot make Data writable | Stop. Do not disable SIP to force it. |
| Complete backup already exists | A previous apply or older backup exists. Inspect it and use restore; do not delete it just to rerun apply. |
| Restore failed | Keep every backup, photograph the error, and report it. Avoid further changes. |
| Request returns later | Local marker changes do not remove the organization's enrollment assignment. |

## Exact file changes

Under the selected Data volume's `private/var/db/ConfigurationProfiles/Settings`:

| Marker | Apply action |
| --- | --- |
| `.cloudConfigHasActivationRecord` | Remove after backup |
| `.cloudConfigRecordFound` | Remove after backup |
| `.cloudConfigProfileInstalled` | Create/touch after backup |
| `.cloudConfigRecordNotFound` | Create/touch after backup |

Backups live under `private/var/db/enrollment-marker-backups/`. Interrupted backups without `backup-complete` are not eligible for restore. Every run that changes files must preserve a complete verified backup first. No script can guarantee recovery from disk failure or sudden power loss.

## Compatibility and reports

| Environment | Evidence |
| --- | --- |
| macOS 27 | Owner reported the Settings request disappeared after the original reset and a restart on 12 November 2026. |
| Recovery comparator fallback | The owner successfully ran `cmp` from the mounted Macintosh HD System volume. |
| Revised guided helper | Shell syntax and isolated backup/restore tests; real Recovery validation pending. |
| Other macOS versions and architectures | Not confirmed. |

Use the issue forms to report results. Include macOS version/build, Apple silicon or Intel, the helper version, sanitized output, and whether the request stayed gone after a restart. Hide passwords, recovery keys, serial numbers, and email addresses from screenshots.

## Development

```sh
bash -n enrollment-markers.sh
bash tests/backup-restore.sh
```

Tests use temporary fixtures; they do not edit a Mac's enrollment settings. Linux CI cannot validate APFS, FileVault, Recovery detection, or the Settings result. macOS CI also runs the isolated tests, not a Recovery reset.

The marker approach was informed by [assafdori/bypass-mdm](https://github.com/assafdori/bypass-mdm) (previous review referenced commit `fc91fec`, MIT). This helper omits its account creation, setup bypass, and disk renaming. See [LICENSE](LICENSE).
