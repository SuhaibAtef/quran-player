#!/usr/bin/env pwsh
# Test-on-commit hook. Triggered by PreToolUse on Bash.
# Watches for `git commit` invocations; runs `flutter test` first and
# blocks the commit (exit 2) on failure so the agent receives the test
# output via stderr and can fix-and-retry without human intervention.

$ErrorActionPreference = 'Continue'

try {
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

$cmd = $payload.tool_input.command
if (-not $cmd) { exit 0 }

# Only fire for `git commit` (any flag form). Skip `git commit-tree`
# and other plumbing variants by anchoring on a word boundary.
if ($cmd -notmatch '\bgit\s+commit(\s|$)') { exit 0 }

# Avoid recursion if the hook itself ends up shelling out to git commit.
if ($env:CLAUDE_HOOK_PRE_COMMIT_TESTS -eq 'running') { exit 0 }
$env:CLAUDE_HOOK_PRE_COMMIT_TESTS = 'running'

try {
    $output = & flutter test 2>&1
    $code = $LASTEXITCODE
} finally {
    Remove-Item Env:CLAUDE_HOOK_PRE_COMMIT_TESTS -ErrorAction SilentlyContinue
}

if ($code -eq 0) { exit 0 }

[Console]::Error.WriteLine("flutter test failed (exit $code) — commit blocked.")
[Console]::Error.WriteLine("Fix the failures below, re-stage, and try the commit again.")
[Console]::Error.WriteLine('---')
[Console]::Error.WriteLine($output -join "`n")
exit 2
