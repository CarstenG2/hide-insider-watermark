# Windows 11 Insider Preview: remove / hide the "Evaluation copy" desktop watermark and keep the wallpaper (no black background, no third-party tool)

$taskFolder  = '\Microsoft\Windows\Shell'
$taskName    = 'Hide Insider Watermark'
$installDir  = "$env:ProgramFiles\HideInsiderWatermark"
$installPath = "$installDir\Hide-InsiderWatermark.ps1"
$powershell  = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$desktopKey  = 'HKCU:\Control Panel\Desktop'

# check if the task is installed:
$scheduler = New-Object -ComObject Schedule.Service
$scheduler.Connect()
$folder = $scheduler.GetFolder($taskFolder)
$isInstalled = $false
try { $isInstalled = [bool]$folder.GetTask($taskName) } catch {}

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

        $trigger = $task.Triggers.Create(9)
        $trigger.UserId = $identity.Name

        $action = $task.Actions.Create(0)
        $action.Path = $powershell
        $action.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installPath`""

        $null = $folder.RegisterTaskDefinition($taskName, $task, 6, $null, $null, 3)
    }
}

# load the Windows functions:
$user32 = Add-Type -Name User32 -PassThru -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool SystemParametersInfo(uint action, uint param, IntPtr value, uint flags);
'@

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

# save the profile value:
$savedMask = (Get-ItemProperty $desktopKey).UserPreferencesMask

# keep the setting if the user turned it on:
$removeBackgroundImages = 0x01
if ($savedMask[4] -band $removeBackgroundImages) { exit }

# hide the watermark:
$setDisableOverlappedContent = 0x1041
$saveAndBroadcast = 0x3
$null = $user32::SystemParametersInfo($setDisableOverlappedContent, 0, [IntPtr]1, $saveAndBroadcast)

# restore the profile value:
Set-ItemProperty $desktopKey -Name UserPreferencesMask -Value $savedMask
