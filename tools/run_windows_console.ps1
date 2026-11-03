param([Parameter(Mandatory = $true)][string]$JobFile)
$ErrorActionPreference = 'Stop'
$job = Get-Content -LiteralPath $JobFile -Raw | ConvertFrom-Json
$result = @{ exit_code = -1; timed_out = $false; error = $null }
try {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $job.executable
    $process.StartInfo.Arguments = $job.arguments
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($job.timeout_ms)) {
        $result.timed_out = $true
        $process.Kill()
        $process.WaitForExit()
    }
    [System.IO.File]::WriteAllText($job.log, $stdout.Result + $stderr.Result)
    $result.exit_code = $process.ExitCode
    $process.Dispose()
} catch { $result.error = $_.Exception.Message }
[System.IO.File]::WriteAllText($job.result, ($result | ConvertTo-Json -Compress))
if ($result.exit_code -ne 0 -or $result.error -or $result.timed_out) { exit 1 }
