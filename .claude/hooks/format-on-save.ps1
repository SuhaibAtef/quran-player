#!/usr/bin/env pwsh
# Auto-format hook. Triggered by PostToolUse on Edit|Write.
# Runs `dart format` on the touched file when it's a Dart source.
# Stays silent for non-Dart edits and never blocks the agent.

$ErrorActionPreference = 'Stop'

try {
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

$file = $payload.tool_input.file_path
if (-not $file) { exit 0 }
if (-not (Test-Path -LiteralPath $file)) { exit 0 }
if ($file -notlike '*.dart') { exit 0 }

# `dart format` rewrites the file in place. Suppress its chatter; only
# surface failures (missing dart binary, parse error) to the user.
$output = & dart format $file 2>&1
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("dart format failed on ${file}:")
    [Console]::Error.WriteLine($output -join "`n")
}

exit 0
