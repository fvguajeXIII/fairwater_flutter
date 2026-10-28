$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutter = (Get-Command flutter -ErrorAction Stop).Source
$port = 8080
$logPath = Join-Path $env:TEMP 'fairwater_flutter_live_preview.log'

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $env:ComSpec
$startInfo.Arguments = "/d /s /c `"`"$flutter`" run --no-pub -d web-server --web-hostname 0.0.0.0 --web-port $port`""
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true

Remove-Item $logPath -Force -ErrorAction SilentlyContinue
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$process.EnableRaisingEvents = $true
$null = $process.Start()

$null = Register-ObjectEvent $process OutputDataReceived -SourceIdentifier 'FairWaterPreview.Output'
$null = Register-ObjectEvent $process ErrorDataReceived -SourceIdentifier 'FairWaterPreview.Error'
$process.BeginOutputReadLine()
$process.BeginErrorReadLine()

$watchers = @()
$watcherIds = @()
foreach ($folder in @('lib', 'assets', 'web')) {
    $path = Join-Path $projectRoot $folder
    if (-not (Test-Path $path)) { continue }
    $watcher = [System.IO.FileSystemWatcher]::new($path, '*')
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::Size
    foreach ($eventName in @('Changed', 'Created', 'Renamed')) {
        $id = "FairWaterPreview.$folder.$eventName"
        $null = Register-ObjectEvent $watcher $eventName -SourceIdentifier $id
        $watcherIds += $id
    }
    $watcher.EnableRaisingEvents = $true
    $watchers += $watcher
}

$previewReady = $false
$lastChange = [datetime]::MinValue
$logPosition = 0L
$utf8 = [System.Text.UTF8Encoding]::new($false)
$logStream = [System.IO.File]::Open($logPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
$writer = [System.IO.StreamWriter]::new($logStream, $utf8)
$writer.AutoFlush = $true

Write-Host "Avvio preview Flutter su http://0.0.0.0:$port; attendo la compilazione iniziale..."
Write-Host 'Salvataggi in lib/, assets/ e web/ invieranno automaticamente hot reload. Premi q per fermare.'

try {
    while (-not $process.HasExited) {
        foreach ($event in @(Get-Event | Where-Object { $_.SourceIdentifier -like 'FairWaterPreview.*' })) {
            $identifier = $event.SourceIdentifier
            if ($identifier -eq 'FairWaterPreview.Output' -or $identifier -eq 'FairWaterPreview.Error') {
                $line = $event.SourceEventArgs.Data
                if ($line) {
                    $writer.WriteLine($line)
                    if ($identifier -eq 'FairWaterPreview.Error') { Write-Host $line -ForegroundColor Red } else { Write-Host $line }
                    if ($line -match 'is being served at') { $previewReady = $true }
                }
            } else {
                $lastChange = [datetime]::UtcNow
            }
            Remove-Event -EventIdentifier $event.EventIdentifier
        }

        if (Test-Path $logPath) {
            $logInfo = Get-Item $logPath
            if ($logInfo.Length -gt $logPosition) {
                $logStream.Flush()
                $logPosition = $logInfo.Length
            }
        }

        if ($previewReady -and $lastChange -ne [datetime]::MinValue -and ([datetime]::UtcNow - $lastChange).TotalSeconds -ge 1.5) {
            $process.StandardInput.WriteLine('r')
            $process.StandardInput.Flush()
            Write-Host 'Modifiche salvate: hot reload richiesto.' -ForegroundColor Cyan
            $lastChange = [datetime]::MinValue
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'q') {
                $process.StandardInput.WriteLine('q')
                $process.StandardInput.Flush()
            }
        }

        Start-Sleep -Milliseconds 250
    }
} finally {
    foreach ($watcher in $watchers) { $watcher.Dispose() }
    foreach ($id in $watcherIds) { Unregister-Event -SourceIdentifier $id -ErrorAction SilentlyContinue }
    Unregister-Event -SourceIdentifier 'FairWaterPreview.Output' -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier 'FairWaterPreview.Error' -ErrorAction SilentlyContinue
    if (-not $process.HasExited) { $process.Kill() }
    $writer.Dispose()
    $process.Dispose()
}
