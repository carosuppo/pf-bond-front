param(
    [string]$Adb = 'adb',
    [string]$Serial,
    [ValidateRange(2, 60)][int]$IntervalSeconds = 5,
    [ValidateRange(1, 120)][int]$Minutes = 30,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'captures')
)
$ErrorActionPreference = 'Stop'
$adbPath = (Get-Command $Adb -ErrorAction Stop).Source
if ($Serial -and $Serial -notmatch '^[a-zA-Z0-9._:-]+$') { throw 'Serial no valido.' }
$prefix = if ($Serial) { "-s $Serial " } else { '' }
$captureDirectory = Join-Path $OutputDirectory (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
New-Item -ItemType Directory -Path $captureDirectory -Force | Out-Null

function Start-Adb([string]$Arguments) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $adbPath
    $info.Arguments = $prefix + $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    return $process
}

function Read-Adb([string]$Arguments) {
    $process = Start-Adb $Arguments
    try {
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) { throw "Timeout adb: $Arguments" }
        if ($process.ExitCode -ne 0 -and -not ($Arguments -eq 'shell pidof com.example.bond_front' -and $process.ExitCode -eq 1)) { throw "Fallo adb: $Arguments (exit $($process.ExitCode))" }
        return $output.GetAwaiter().GetResult()
    } finally {
        if (-not $process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
}

$logcat = $null
$writer = $null
try {
    $state = Read-Adb 'get-state'
    if ($state.Trim() -ne 'device') { throw 'Se requiere un dispositivo autorizado.' }
    @(
        "hostUtc=$([DateTime]::UtcNow.ToString('o'))"
        "deviceEpoch=$(Read-Adb 'shell date +%s')"
        "package=com.example.bond_front intervalSeconds=$IntervalSeconds minutes=$Minutes"
        'SENSITIVE: diagnostic coordinates; do not publish raw captures.'
        'meminfo contains Android PSS/RSS in kB, not Dart heap.'
        'logcat is allowlisted: BOND_DIAG and selected numeric-failure/system lines only.'
    ) | Set-Content (Join-Path $captureDirectory 'metadata.txt') -Encoding UTF8
    $writer = New-Object IO.StreamWriter((Join-Path $captureDirectory 'logcat.txt'), $false)
    $writer.AutoFlush = $true
    # No logcat -c: preserve the device's existing logs. -T 1 starts at the tail.
    $logcat = Start-Adb 'logcat -v epoch -b main -b system -b crash -T 1 flutter:I ActivityManager:I lmkd:I lowmemorykiller:I AndroidRuntime:E *:S'
    $stderr = $logcat.StandardError.ReadToEndAsync()
    $lineTask = $logcat.StandardOutput.ReadLineAsync()
    $deadline = [DateTime]::UtcNow.AddMinutes($Minutes)
    $nextSample = [DateTime]::MinValue
    $characters = 0
    Write-Host "Captura: $captureDirectory. Detener con Q o Ctrl+C. Limite: $Minutes minutos / 32 MiB logcat."
    while ([DateTime]::UtcNow -lt $deadline -and $characters -lt 32MB) {
        if ($lineTask.IsCompleted) {
            $line = $lineTask.GetAwaiter().GetResult()
            if ($null -eq $line) { break }
            if ($line -match '\[BOND_DIAG sensitive_coordinates\]' -or
                $line -match '^.*(?:lmkd|lowmemorykiller).*com\.example\.bond_front' -or
                $line -match 'ActivityManager.*(?:ANR in com\.example\.bond_front|Process com\.example\.bond_front .*has died)' -or
                $line -match 'Unsupported operation: Infinity or NaN toInt' -or
                $line -match '^.*flutter.*#\d+\s+.*(?:double\.(?:floor|ceil|round|toInt)|package:flutter_map/src/layer/tile_layer/)') {
                $writer.WriteLine($line)
                $characters += [Text.Encoding]::UTF8.GetByteCount($line) + 2
            }
            $lineTask = $logcat.StandardOutput.ReadLineAsync()
        } else {
            Start-Sleep -Milliseconds 20
        }
        if ([DateTime]::UtcNow -ge $nextSample) {
            $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
            $pids = Read-Adb 'shell pidof com.example.bond_front'
            "hostUtc=$([DateTime]::UtcNow.ToString('o')) pid=$($pids.Trim())" |
                Add-Content (Join-Path $captureDirectory 'timeline.txt')
            Read-Adb 'shell dumpsys meminfo com.example.bond_front' |
                Set-Content (Join-Path $captureDirectory "meminfo-$stamp.txt") -Encoding UTF8
            $nextSample = [DateTime]::UtcNow.AddSeconds($IntervalSeconds)
        }
        if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq 'Q') { break }
        }
    }
} finally {
    if ($null -ne $logcat) {
        if (-not $logcat.HasExited) { $logcat.Kill() }
        $logcat.Dispose()
    }
    if ($null -ne $writer) { $writer.Dispose() }
    Write-Host "Archivos guardados en $captureDirectory"
}
