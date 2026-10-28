# Hide Insider Watermark

Hides the **"Evaluation copy"** desktop watermark on **Windows 11 Insider Preview** builds and **keeps your wallpaper**. One PowerShell script, no third-party tool, no patched system files.

```
Windows 11 Enterprise Insider Preview
Evaluation copy. Build 28020.3142.br_release_svc_betaflt_prod1.260924-1829
```

## The problem

Insider Preview builds paint a build watermark in the bottom-right corner of the desktop. The common tip to hide it is the Ease of Access setting **"Remove background images (where available)"**. It does hide the watermark, but from the next sign-in on the desktop stays **black**: Windows loads the wallpaper only once at sign-in, and with that setting saved in the profile it loads no image at all. Reinstalling Windows over itself does not help, because the setting lives in the user profile.

## How it works

The watermark follows the setting at once; a wallpaper that is already loaded stays when the setting is switched on. The script uses that difference:

1. At sign-in it waits until the shell signals that the desktop is shown (`ShellDesktopSwitchEvent`).
2. It saves `UserPreferencesMask` from `HKCU\Control Panel\Desktop`.
3. It reads the background type and the wallpaper path. For a picture background with an existing file, it switches "Remove background images" off and sets the same wallpaper again with `SystemParametersInfo(SPI_SETDESKWALLPAPER)`, so the picture is loaded fresh before the watermark is hidden.
4. It switches "Remove background images" on with `SystemParametersInfo(SPI_SETDISABLEOVERLAPPEDCONTENT)`, saved and announced like the Apply button. The watermark disappears; the loaded wallpaper stays.
5. It writes the saved `UserPreferencesMask` back. The profile keeps the setting off, so the next sign-in loads the wallpaper again.
6. It stays running in the background with a hidden window. Windows redraws the desktop after events such as switching Bluetooth on or off, plugging in a device, changing the display or unlocking, and with the setting on, the redraw leaves a solid colour instead of the picture. The window receives the messages Windows sends for these events (`WM_DEVICECHANGE`, `WM_DISPLAYCHANGE`, `WM_SETTINGCHANGE`, `WM_THEMECHANGED`, `WM_DWMCOMPOSITIONCHANGED`, `WM_WTSSESSION_CHANGE`, `TaskbarCreated`). Half a second after the last of them, it repeats steps 2 to 5 once.

If "Remove background images" is already on in the profile, because you use it on purpose, the script exits and leaves it as it is.

The setting is only switched on for the running session. Nothing outside your own registry hive (`HKCU`) is changed at run time.

The task starts the script, which hands its own code to a second PowerShell through standard input and exits. That second process is the one that stays, so it shows in Task Manager as `powershell.exe` with no parameters on its command line. Only one copy runs at a time.

## Requirements

- Windows 11 Insider Preview
- Windows PowerShell 5.1 (built into Windows)
- Administrator rights **once**, for the set-up

## Installation

1. Download `Hide-InsiderWatermark.ps1` from the [latest release](https://github.com/CarstenG2/hide-insider-watermark/releases/latest).
2. Right-click the file and choose **Run with PowerShell**.
3. Confirm the UAC prompt.

The script sets itself up on first use:

- it copies itself to `C:\Program Files\HideInsiderWatermark\`, where standard users cannot change it,
- it registers the scheduled task `\Microsoft\Windows\Shell\Hide Insider Watermark`, which runs the script at every sign-in of your user account, **without** elevation, with no time limit and on battery as well, with no console window,
- it starts the task, which hides the watermark right away and keeps running for the session.

To update from an earlier version, run the new script once the same way, then sign out and in. It replaces the task definition; a copy that is already running keeps working until sign-out.

If Windows blocks the downloaded file, unblock it first: file properties > **Unblock**, or `Unblock-File .\Hide-InsiderWatermark.ps1`.

## Uninstall

1. Task Scheduler > Task Scheduler Library > Microsoft > Windows > Shell: end and delete **Hide Insider Watermark**.
2. Delete the folder `C:\Program Files\HideInsiderWatermark`.

The watermark returns with the next sign-in.

## Changing the wallpaper

While the watermark is hidden, "Remove background images" is on for the running session. *Settings > Personalization > Background* then shows no picture, colour or slideshow options, and its preview is black. Themes can still be applied.

To pick a different wallpaper:

1. Open the Control Panel: press the **Start** button, type `Control Panel` and select it.
2. Select **Ease of Access**. This is the default view, **View by: Category**; in the icon views, select **Ease of Access Center** directly and continue with step 4.
3. Select **Ease of Access Center**.
4. Under *Explore all settings*, select **Make the computer easier to see**.
5. Scroll down to *Make things on the screen easier to see*, clear **Remove background images (where available)** and click **OK**. The watermark appears again right away, which confirms the right box.
6. Open *Settings > Personalization > Background* and choose the new wallpaper. If the Background page was already open, it does not refresh on its own: go back one level to *Personalization* and open *Background* again.

Leave the box cleared. At the next sign-in the task hides the watermark again and keeps the new wallpaper. Ticking the box yourself would save the setting in the profile, and the desktop would stay black from the next sign-in on.

## Limitations

- The watermark stays visible for a few seconds after sign-in, until the desktop is shown and the script switches the setting.
- The watermark is shown on a solid colour background as well. With a solid colour the script hides the watermark and the colour stays. Slideshow backgrounds are untested.
- After an event that redraws the desktop, the solid colour shows for about two seconds and the watermark flashes briefly, until the picture is set again.
- A redraw that Windows announces with none of the messages listed under "How it works" leaves the solid colour until the next such message. Signing out and in restores the picture as well.
- If the script is ended during the session, the solid colour stays after the next redraw until the next sign-in.
- Choosing a new wallpaper in Settings while the setting is on leaves a solid colour. See "Changing the wallpaper".
- An Insider update may change how Windows handles this setting. If the desktop turns black after an update, delete the task and check whether the setting behaves as described above.

## Troubleshooting

| Symptom | Check |
|---|---|
| Desktop black after sign-in | `UserPreferencesMask` in `HKCU\Control Panel\Desktop`: the fifth byte must have bit `0x01` cleared. Turn "Remove background images" off in Ease of Access, sign out and in. |
| Watermark still visible | Task Scheduler: task present and running (`0x41301`). || Script does not start | Execution policy or a blocked download, see Installation. |

## License

[MIT](LICENSE)
