param(
    [string]$ProgramDataDir = "C:\ProgramData\SetuLink",
    [int]$AgentTailLines = 240,
    [int]$InstallerTailLines = 200
)

$ErrorActionPreference = "Stop"

$DiagnosticsDir = Join-Path $ProgramDataDir "diagnostics"
$LogsDir = Join-Path $ProgramDataDir "logs"
$ConfigPath = Join-Path $ProgramDataDir "config\agent.json"
$InstallerLog = Join-Path $LogsDir "installer.log"
$AgentLog = Join-Path $LogsDir "agent.log"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BundlePath = Join-Path $DiagnosticsDir "manual-log-bundle-$Stamp.zip"
$SummaryPath = Join-Path $DiagnosticsDir "latest-manual-log-diagnostics.json"
$WorkDir = Join-Path $env:TEMP "setulink-log-bundle-$Stamp"

New-Item -ItemType Directory -Force -Path $DiagnosticsDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir "logs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir "summary") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir "config") | Out-Null

$included = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

function Copy-IfExists {
    param([string]$Source, [string]$Dest, [string]$Name)
    if (Test-Path $Source) {
        Copy-Item $Source $Dest -Force
        $included.Add($Name)
    } else {
        $missing.Add("$Name missing at $Source")
    }
}

Copy-IfExists $InstallerLog (Join-Path $WorkDir "logs\installer.log") "logs/installer.log"
Copy-IfExists $AgentLog (Join-Path $WorkDir "logs\agent.log") "logs/agent.log"

if (Test-Path $ConfigPath) {
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        foreach ($key in @("agentToken", "token", "secret", "password")) {
            if ($config.PSObject.Properties.Name -contains $key) {
                $config.$key = "<redacted>"
            }
        }
        $config | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $WorkDir "config\agent.redacted.json") -Encoding UTF8
        $included.Add("config/agent.redacted.json")
    } catch {
        "config redact failed: $($_.Exception.Message)" | Set-Content (Join-Path $WorkDir "config\agent.redacted.json") -Encoding UTF8
        $included.Add("config/agent.redacted.json")
    }
} else {
    $missing.Add("config/agent.redacted.json missing at $ConfigPath")
}

if (Test-Path $AgentLog) {
    Get-Content $AgentLog -Tail $AgentTailLines | Set-Content (Join-Path $WorkDir "summary\agent-log-tail.txt") -Encoding UTF8
    $included.Add("summary/agent-log-tail.txt")
}
if (Test-Path $InstallerLog) {
    Get-Content $InstallerLog -Tail $InstallerTailLines | Set-Content (Join-Path $WorkDir "summary\installer-log-tail.txt") -Encoding UTF8
    $included.Add("summary/installer-log-tail.txt")
}

$service = Get-Service -Name "SetuLinkAgent" -ErrorAction SilentlyContinue
$serviceText = if ($service) {
    "name=SetuLinkAgent`nexists=true`nstate=$($service.Status)`n"
} else {
    "name=SetuLinkAgent`nexists=false`n"
}
$serviceText | Set-Content (Join-Path $WorkDir "summary\service-status.txt") -Encoding UTF8
$included.Add("summary/service-status.txt")

$patterns = @("ERROR", "WARN", "remote-desktop", "stream-stalled", "stream-recover", "first-frame", "encoder-mode", "input-latency", "heartbeat", "registration")
$patternCounts = @{}
if (Test-Path $AgentLog) {
    $agentText = Get-Content $AgentLog -Raw
    foreach ($pattern in $patterns) {
        $patternCounts[$pattern] = ([regex]::Matches($agentText, [regex]::Escape($pattern))).Count
    }
}

$summary = [PSCustomObject]@{
    collectedAt = (Get-Date).ToString("o")
    status = "manual"
    installerLogPath = $InstallerLog
    agentLogPath = $AgentLog
    configPath = $ConfigPath
    bundlePath = $BundlePath
    serviceName = "SetuLinkAgent"
    serviceExists = [bool]$service
    serviceState = if ($service) { [string]$service.Status } else { "" }
    programDataDir = $ProgramDataDir
    filesIncluded = @($included)
    filesMissing = @($missing)
    recentLogPatterns = $patternCounts
}

$summary | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $WorkDir "summary\manual-log-diagnostics.json") -Encoding UTF8
$summary | ConvertTo-Json -Depth 8 | Set-Content $SummaryPath -Encoding UTF8

if (Test-Path $BundlePath) {
    Remove-Item $BundlePath -Force
}
Compress-Archive -Path (Join-Path $WorkDir "*") -DestinationPath $BundlePath -Force
Remove-Item $WorkDir -Recurse -Force

Write-Host "SETULINK LOG COLLECTION: PASS"
Write-Host "Diagnostics bundle: $BundlePath"
Write-Host "Summary: $SummaryPath"
