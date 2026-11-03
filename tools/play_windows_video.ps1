param([Parameter(Mandatory = $true)][string]$VideoPath, [switch]$SaveToVideos, [switch]$FocusOnly, [string]$ResultPath, [switch]$RestartVideo)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $VideoPath)) { throw "Video does not exist: $VideoPath" }
if ($SaveToVideos) {
    $folder = [Environment]::GetFolderPath('MyVideos')
    if (-not $folder) { throw 'Windows Videos folder is unavailable.' }
    [void][System.IO.Directory]::CreateDirectory($folder)
    $target = Join-Path $folder 'Close-the-Gap-60fps.mp4'
    $number = 1
    while (Test-Path -LiteralPath $target) {
        $target = Join-Path $folder ("Close-the-Gap-60fps-{0}.mp4" -f $number)
        $number++
    }
    [System.IO.File]::Copy($VideoPath, $target, $false)
    $VideoPath = $target
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CloseTheGapVideoWindow {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@

if (-not $FocusOnly) { Start-Process -FilePath $VideoPath }
$playerNames = @('Microsoft.Media.Player', 'Music.UI', 'Video.UI', 'wmplayer', 'vlc', 'mpv', 'mpc-hc', 'mpc-hc64', 'mpc-be', 'mpc-be64', 'MediaPlayer')
$player = $null
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 500
    $player = Get-Process | Where-Object {
        $_.MainWindowHandle -ne 0 -and ($_.ProcessName -in $playerNames -or
            ($_.ProcessName -eq 'ApplicationFrameHost' -and $_.MainWindowTitle -in @('Media Player', 'Movies & TV')))
    } |
        Sort-Object StartTime -Descending | Select-Object -First 1
    if ($player) { break }
}
if (-not $player) { throw 'The video was launched, but a supported player window was not found.' }

[void][CloseTheGapVideoWindow]::ShowWindowAsync($player.MainWindowHandle, 3)
$shell = New-Object -ComObject WScript.Shell
[void]$shell.AppActivate($player.Id)
[void][CloseTheGapVideoWindow]::SetForegroundWindow($player.MainWindowHandle)
Start-Sleep -Milliseconds 300
$focused = [CloseTheGapVideoWindow]::GetForegroundWindow() -eq $player.MainWindowHandle
if (-not $focused) {
    $rect = New-Object CloseTheGapVideoWindow+Rect
    $cursor = New-Object CloseTheGapVideoWindow+Point
    if (-not [CloseTheGapVideoWindow]::GetWindowRect($player.MainWindowHandle, [ref]$rect)) { throw 'Unable to locate the player window.' }
    $restoreCursor = [CloseTheGapVideoWindow]::GetCursorPos([ref]$cursor)
    try {
        # The user explicitly requested foreground playback. Click only this
        # window's title bar; restore its normal stacking and the pointer.
        [void][CloseTheGapVideoWindow]::SetWindowPos($player.MainWindowHandle, [IntPtr](-1), 0, 0, 0, 0, 0x53)
        Start-Sleep -Milliseconds 100
        [void][CloseTheGapVideoWindow]::SetCursorPos([int](($rect.Left + $rect.Right) / 2), $rect.Top + 20)
        [CloseTheGapVideoWindow]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
        [CloseTheGapVideoWindow]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 100
    } finally {
        if ($restoreCursor) { [void][CloseTheGapVideoWindow]::SetCursorPos($cursor.X, $cursor.Y) }
        [void][CloseTheGapVideoWindow]::SetWindowPos($player.MainWindowHandle, [IntPtr](-2), 0, 0, 0, 0, 0x53)
    }
    $focused = [CloseTheGapVideoWindow]::GetForegroundWindow() -eq $player.MainWindowHandle
}
$loaded = $false
$playing = $false
$playbackControls = @()
if ($focused -and $player.ProcessName -eq 'ApplicationFrameHost') {
    Add-Type -AssemblyName UIAutomationClient
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($player.MainWindowHandle)
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        $items = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $loaded = @($items | Where-Object { $_.Current.Name -match 'Close the Gap - Recorded forest bot session' }).Count -gt 0
        if ($loaded) { break }
        Start-Sleep -Milliseconds 200
    }
    if ($loaded) {
        foreach ($element in $items) {
            if ($element.Current.Name -match '^Play($|\s|\()') {
                $invoke = $null
                if ($element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) {
                    $invoke.Invoke()
                    Start-Sleep -Milliseconds 700
                    break
                }
            }
        }
        $items = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $playing = @($items | Where-Object { $_.Current.Name -match '^Pause($|\s|\()' }).Count -gt 0
        $playbackControls = @($items | Where-Object { $_.Current.Name -match '^Play|^Pause' } | ForEach-Object { $_.Current.Name })
    }
}
$mediaState = $null
$mediaError = $null
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
    $propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
        $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    function Await-Media($operation, [type]$type) {
        $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
        if (-not $task.Wait(5000)) { throw 'Windows media operation timed out.' }
        return $task.Result
    }
    $manager = Await-Media ($managerType::RequestAsync()) $managerType
    foreach ($session in $manager.GetSessions()) {
        if ($session.SourceAppUserModelId -notmatch 'Microsoft.ZuneMusic') { continue }
        $properties = Await-Media ($session.TryGetMediaPropertiesAsync()) $propertiesType
        if ($properties.Title -notmatch '^Close the Gap - Recorded forest bot session') { continue }
        $loaded = $true
        $beforeStatus = $session.GetPlaybackInfo().PlaybackStatus.ToString()
        $seekAccepted = $null
        if ($RestartVideo -or $beforeStatus -ne 'Playing') {
            $seekAccepted = Await-Media ($session.TryChangePlaybackPositionAsync(0)) ([bool])
        }
        $playAccepted = Await-Media ($session.TryPlayAsync()) ([bool])
        $beforePosition = $session.GetTimelineProperties().Position.TotalSeconds
        Start-Sleep -Milliseconds 1200
        $afterPosition = $session.GetTimelineProperties().Position.TotalSeconds
        $status = $session.GetPlaybackInfo().PlaybackStatus.ToString()
        $playing = $playAccepted -and $status -eq 'Playing'
        $mediaState = @{ title = $properties.Title; status = $status; playAccepted = $playAccepted; seekAccepted = $seekAccepted; rate = $session.GetPlaybackInfo().PlaybackRate; positionBefore = $beforePosition; positionAfter = $afterPosition }
        break
    }
} catch { $mediaError = $_.Exception.Message }
$focused = [CloseTheGapVideoWindow]::GetForegroundWindow() -eq $player.MainWindowHandle
$result = @{ video = $VideoPath; player = $player.ProcessName; foreground = $focused; expectedVideoLoaded = $loaded; playing = $playing; playbackControls = $playbackControls; mediaState = $mediaState; mediaError = $mediaError } | ConvertTo-Json -Compress -Depth 3
if ($ResultPath) { [System.IO.File]::WriteAllText($ResultPath, $result) }
$result
if (-not $focused) { throw 'Windows did not confirm that the video player has foreground focus.' }
if ($player.ProcessName -eq 'ApplicationFrameHost' -and (-not $loaded -or -not $playing)) { throw 'Windows did not confirm playback of the expected gameplay video.' }
