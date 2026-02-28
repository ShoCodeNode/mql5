param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFile,

    [string]$MetaEditorPath = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$terminalRoot = Split-Path $workspaceRoot -Parent

$resolvedSource = Resolve-Path -Path $SourceFile -ErrorAction SilentlyContinue
if (-not $resolvedSource) {
    Write-Error "Source file not found: $SourceFile"
    exit 1
}
$resolvedSourcePath = $resolvedSource.Path

if ([string]::IsNullOrWhiteSpace($MetaEditorPath)) {
    if ($env:MQL_METAEDITOR_PATH -and (Test-Path $env:MQL_METAEDITOR_PATH)) {
        $MetaEditorPath = $env:MQL_METAEDITOR_PATH
    }
    elseif (Test-Path (Join-Path $terminalRoot "metaeditor64.exe")) {
        $MetaEditorPath = Join-Path $terminalRoot "metaeditor64.exe"
    }
    elseif (Test-Path (Join-Path $terminalRoot "origin.txt")) {
        $originDir = (Get-Content (Join-Path $terminalRoot "origin.txt") -TotalCount 1).Trim()
        $candidate = Join-Path $originDir "metaeditor64.exe"
        if (Test-Path $candidate) {
            $MetaEditorPath = $candidate
        }
    }
    else {
        $cmd = Get-Command metaeditor64.exe -ErrorAction SilentlyContinue
        if ($cmd) {
            $MetaEditorPath = $cmd.Source
        }
    }
}

if ([string]::IsNullOrWhiteSpace($MetaEditorPath) -or -not (Test-Path $MetaEditorPath)) {
    Write-Error "metaeditor64.exe was not found. Set mql_tools.Metaeditor.Metaeditor5Dir in VS Code settings, or set MQL_METAEDITOR_PATH env var."
    exit 1
}

$programName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedSourcePath)
$logDir = Join-Path $workspaceRoot "Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir ("compile_{0}.log" -f $programName)

Write-Host "Compiling: $resolvedSourcePath"
Write-Host "MetaEditor: $MetaEditorPath"
Write-Host "Log: $logFile"

& $MetaEditorPath "/compile:$resolvedSourcePath" "/log:$logFile"
$exitCode = $LASTEXITCODE

for ($i = 0; $i -lt 20; $i++) {
    if (Test-Path $logFile) {
        break
    }
    Start-Sleep -Milliseconds 200
}

if (-not (Test-Path $logFile)) {
    Write-Error "Compile log was not generated: $logFile"
    exit 1
}

$resultLine = Select-String -Path $logFile -Pattern "^Result:\s+" | Select-Object -Last 1
if ($resultLine) {
    Write-Host $resultLine.Line
}
else {
    Write-Warning "Result line not found in compile log."
}

if ($resultLine -and $resultLine.Line -match "Result:\s+0 errors,\s+0 warnings") {
    exit 0
}

if ($exitCode -ne 0) {
    exit $exitCode
}

exit 1
