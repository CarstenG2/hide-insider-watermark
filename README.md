# Hide Insider Watermark

Hides the **"Evaluation copy"** desktop watermark on **Windows 11 Insider Preview** builds and **keeps your wallpaper**. One PowerShell script, no third-party tool, no patched system files.

```
Windows 11 Enterprise Insider Preview
Evaluation copy. Build 28020.3142.br_release_svc_betaflt_prod1.260924-1829
```

## The problem

Insider Preview builds paint a build watermark in the bottom-right corner of the desktop. The common tip to hide it is the Ease of Access setting **"Remove background images (where available)"**. It does hide the watermark, but from the next sign-in on the desktop stays **black**: Windows loads the wallpaper only once at sign-in, and with that setting saved in the profile it loads no image at all. Reinstalling Windows over itself does not help, because the setting lives in the user profile.

## How it works

The watermark follows the setting at once; the wallpaper is read only at sign-in. The script uses that difference:

1. At sign-in it waits until the shell signals that the desktop is shown (`ShellDesktopSwitchEvent`), so the wallpaper is already loaded.
2. It saves `UserPreferencesMask` from `HKCU\Control Panel\Desktop`.
3. It switches "Remove background images" on with `SystemParametersInfo(SPI_SETDISABLEOVERLAPPEDCONTENT)`, saved and announced like the Apply button. The watermark disappears; the loaded wallpaper stays.
4. It writes the saved `UserPreferencesMask` back. The profile keeps the setting off, so the next sign-in loads the wallpaper again.

The setting is only switched on for the running session. Nothing outside your own registry hive (`HKCU`) is changed at run time.

## Requirements

- Windows 11 Insider Preview with a desktop wallpaper image
- Windows PowerShell 5.1 (built into Windows)
- Administrator rights **once**, for the set-up

## Installation

1. Download `Hide-InsiderWatermark.ps1` from the [latest release](https://github.com/CarstenG2/hide-insider-watermark/releases/latest).
2. Right-click the file and choose **Run with PowerShell**.
3. Confirm the UAC prompt.

The script sets itself up on first use:

- it copies itself to `C:\Program Files\HideInsiderWatermark\`, where standard users cannot change it,
- it registers the scheduled task `\Microsoft\Windows\Shell\Hide Insider Watermark`, which runs the script at every sign-in of your user account, **without** elevation,
- it hides the watermark right away.

If Windows blocks the downloaded file, unblock it first: file properties > **Unblock**, or `Unblock-File .\Hide-InsiderWatermark.ps1`.

## Uninstall

1. Task Scheduler > Task Scheduler Library > Microsoft > Windows > Shell: delete **Hide Insider Watermark**.
2. Delete the folder `C:\Program Files\HideInsiderWatermark`.

The watermark returns with the next sign-in.

## Limitations

- The watermark stays visible for a few seconds after sign-in, until the desktop is shown and the script switches the setting.
- With a solid colour background the script works as well, but it is not needed: without an image there is nothing to lose, and "Remove background images" can simply stay on.
- An Insider update may change how Windows handles this setting. If the desktop turns black after an update, delete the task and check whether the setting behaves as described above.

## Troubleshooting

| Symptom | Check |
|---|---|
| Desktop black after sign-in | `UserPreferencesMask` in `HKCU\Control Panel\Desktop`: the fifth byte must have bit `0x01` cleared. Turn "Remove background images" off in Ease of Access, sign out and in. |
| Watermark still visible | Task Scheduler: task present, last run result `0x0`. |
| Script does not start | Execution policy or a blocked download, see Installation. |

## License

[MIT](LICENSE)
