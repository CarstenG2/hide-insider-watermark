# Windows 11 Insider Preview: remove / hide the "Evaluation copy" desktop watermark and keep the wallpaper (no black background, no third-party tool)

$taskFolder   = '\Microsoft\Windows\Shell'
$taskName     = 'Hide Insider Watermark'
$installDir   = "$env:ProgramFiles\HideInsiderWatermark"
$installPath  = "$installDir\Hide-InsiderWatermark.ps1"
$powershell   = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$conhost      = "$env:SystemRoot\System32\conhost.exe"
$desktopKey   = 'HKCU:\Control Panel\Desktop'
$wallpaperKey ='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
$watcherName  = 'Local\HideInsiderWatermark'
$quietTime    = 500

# check if the task is installed with the sign-in trigger only and without a time limit:
$scheduler = New-Object -ComObject Schedule.Service
$scheduler.Connect()
$folder = $scheduler.GetFolder($taskFolder)
$installedTask = $null
try { $installedTask = $folder.GetTask($taskName).Definition } catch {}
$hasOneTrigger = $installedTask.Triggers.Count -eq 1
$hasNoTimeLimit = $installedTask.Settings.ExecutionTimeLimit -eq 'PT0S'
$isInstalled = $hasOneTrigger -and $hasNoTimeLimit

# install task:
if (-not $isInstalled) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        $setupArguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process $powershell $setupArguments -Verb RunAs
        exit
    }

    if ($isAdmin) {
        $null = New-Item $installDir -ItemType Directory -Force
        Copy-Item $PSCommandPath $installPath -Force

        $task = $scheduler.NewTask(0)
        $task.Principal.UserId = $identity.Name
        $task.Principal.RunLevel = 0

        $task.Settings.ExecutionTimeLimit = 'PT0S'
        $task.Settings.DisallowStartIfOnBatteries = $false
        $task.Settings.StopIfGoingOnBatteries = $false

        $logonTrigger = $task.Triggers.Create(9)
        $logonTrigger.UserId = $identity.Name

        $action = $task.Actions.Create(0)
        $action.Path = $conhost
        $action.Arguments = "--headless `"$powershell`" -NoProfile -ExecutionPolicy Bypass -File `"$installPath`""

        $null = $folder.RegisterTaskDefinition($taskName, $task, 6, $null, $null, 3)
        $null = $folder.GetTask($taskName).Run($null)
        exit
    }
}

# load the Windows functions:
$user32 = Add-Type -Name User32 -PassThru -MemberDefinition @'
// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow
[DllImport("user32.dll")]
public static extern bool SystemParametersInfo(uint action, uint param, IntPtr value, uint flags);

// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
'@

# load the window that hears when Windows redraws the desktop:
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class DesktopChangeWatcher : Form {
    // https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-settingchange
    const int WM_SETTINGCHANGE = 0x001A;

    // https://learn.microsoft.com/en-us/windows/win32/gdi/wm-displaychange
    const int WM_DISPLAYCHANGE = 0x007E;

    // https://learn.microsoft.com/en-us/windows/win32/devio/wm-devicechange
    const int WM_DEVICECHANGE = 0x0219;

    // https://learn.microsoft.com/en-us/windows/win32/termserv/wm-wtssession-change
    const int WM_WTSSESSION_CHANGE = 0x02B1;

    // https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-themechanged
    const int WM_THEMECHANGED = 0x031A;

    // https://learn.microsoft.com/en-us/windows/win32/dwm/wm-dwmcompositionchanged
    const int WM_DWMCOMPOSITIONCHANGED = 0x031E;

    // https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerwindowmessagew
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern uint RegisterWindowMessage(string name);

    // https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/nf-wtsapi32-wtsregistersessionnotification
    [DllImport("wtsapi32.dll")]
    static extern bool WTSRegisterSessionNotification(IntPtr window, int flags);

    public event EventHandler Settled;
    public bool IsPaused;

    readonly Timer quietTimer = new Timer();
    readonly uint taskbarCreated;

    public DesktopChangeWatcher(int quietMilliseconds) {
        // https://learn.microsoft.com/en-us/windows/win32/shell/taskbar
        taskbarCreated = RegisterWindowMessage("TaskbarCreated");
        quietTimer.Interval = quietMilliseconds;
        quietTimer.Tick += OnQuiet;
        WTSRegisterSessionNotification(Handle, 0);
    }

    protected override void WndProc(ref Message m) {
        bool isRedraw = m.Msg == WM_SETTINGCHANGE
            || m.Msg == WM_DISPLAYCHANGE
            || m.Msg == WM_DEVICECHANGE
            || m.Msg == WM_WTSSESSION_CHANGE
            || m.Msg == WM_THEMECHANGED
            || m.Msg == WM_DWMCOMPOSITIONCHANGED
            || m.Msg == taskbarCreated;
        if (isRedraw && !IsPaused) {
            quietTimer.Stop();
            quietTimer.Start();
        }
        base.WndProc(ref m);
    }

    void OnQuiet(object sender, EventArgs e) {
        quietTimer.Stop();
        if (Settled != null) Settled(this, EventArgs.Empty);
    }
}
'@

# name the Windows settings:
$setDisableOverlappedContent = 0x1041
$setDeskWallpaper            = 0x14
$saveAndBroadcast            = 0x3
$removeBackgroundImages      = 0x01

function Test-BackgroundImagesRemoved {
    $mask = (Get-ItemProperty $desktopKey).UserPreferencesMask
    return [bool]($mask[4] -band $removeBackgroundImages)
}

function Update-Desktop {
    # save the profile value:
    $savedMask = (Get-ItemProperty $desktopKey).UserPreferencesMask

    # read the current background:
    $backgroundType = (Get-ItemProperty $wallpaperKey).BackgroundType
    $wallpaper = (Get-ItemProperty $desktopKey).WallPaper
    $isPicture = $backgroundType -eq 0 -and [IO.File]::Exists($wallpaper)

    # load the picture before the watermark is hidden:
    if ($isPicture) {
        $null = $user32::SystemParametersInfo($setDisableOverlappedContent, 0, [IntPtr]0, $saveAndBroadcast)
        $null = $user32::SystemParametersInfo($setDeskWallpaper, 0, $wallpaper, $saveAndBroadcast)
    }

    # hide the watermark:
    $null = $user32::SystemParametersInfo($setDisableOverlappedContent, 0, [IntPtr]1, $saveAndBroadcast)

    # restore the profile value:
    Set-ItemProperty $desktopKey -Name UserPreferencesMask -Value $savedMask
}

# wait for the desktop to appear:
$deadline = (Get-Date).AddMinutes(2)
$desktopEvent = $null
while (-not $desktopEvent -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 100
    try { $desktopEvent = [Threading.EventWaitHandle]::OpenExisting('ShellDesktopSwitchEvent') } catch {}
}
if (-not $desktopEvent) { exit }

$isDesktopReady = $desktopEvent.WaitOne([TimeSpan]::FromMinutes(2))
if (-not $isDesktopReady) { exit }

# keep the setting if the user turned it on:
if (Test-BackgroundImagesRemoved) { exit }

# hide the watermark and keep the picture:
Update-Desktop

# let only one copy stay and watch the desktop:
$watcherLock = [Threading.Mutex]::new($false, $watcherName)
$isWatching = $false
try { $isWatching = $watcherLock.WaitOne(0) } catch [Threading.AbandonedMutexException] { $isWatching = $true }
if (-not $isWatching) { exit }

# set the picture again each time Windows has redrawn the desktop:
$watcher = [DesktopChangeWatcher]::new($quietTime)
$watcher.add_Settled({
    if (Test-BackgroundImagesRemoved) { return }
    $watcher.IsPaused = $true
    Update-Desktop
    $watcher.IsPaused = $false
})
[Windows.Forms.Application]::Run()
