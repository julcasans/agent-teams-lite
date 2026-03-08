#Requires -Version 5.1

<#
.SYNOPSIS
    Smoke tests for the Agent Teams Lite Windows installer (install.ps1)
.DESCRIPTION
    Creates temp directories, runs the installer against them, and asserts
    the correct files are created.  Mirrors the coverage of install_test.sh.
.EXAMPLE
    pwsh -File scripts\install_test.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\install_test.ps1
#>

$ErrorActionPreference = 'Stop'

# ============================================================================
# Paths
# ============================================================================

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoDir    = Split-Path -Parent $ScriptDir
$InstallPs1 = Join-Path $ScriptDir 'install.ps1'

# ============================================================================
# Test state
# ============================================================================

$script:TestsRun    = 0
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:Failures    = @()

# All 13 expected skill directory names
$ExpectedSkills = @(
    'sdd-apply'
    'sdd-archive'
    'sdd-continue'
    'sdd-design'
    'sdd-explore'
    'sdd-ff'
    'sdd-init'
    'sdd-new'
    'sdd-orchestrator'
    'sdd-propose'
    'sdd-spec'
    'sdd-tasks'
    'sdd-verify'
)

# ============================================================================
# Helpers
# ============================================================================

function Write-Header {
    Write-Host ''
    Write-Host ([char]0x2554 + ([string][char]0x2550 * 42) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ([char]0x2551 + '   Agent Teams Lite - Install Tests       ' + [char]0x2551) -ForegroundColor Cyan
    Write-Host ([char]0x255A + ([string][char]0x2550 * 42) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ''
}

function New-TestDir {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "atl-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    return $tmp
}

function Remove-TestDir {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force -Path $Path
    }
}

# Invoke install.ps1 inside a sandboxed environment.
# Overrides USERPROFILE and APPDATA so nothing touches the real user profile.
function Invoke-Installer {
    param(
        [string]$HomeDir,
        [string]$AppDataDir,
        [string[]]$Args
    )

    # Run in a child process to avoid polluting current session env vars
    $escaped = $Args | ForEach-Object { "'$_'" }
    $argStr  = $escaped -join ' '
    $cmd = @"
`$env:USERPROFILE = '$HomeDir'
`$env:APPDATA     = '$AppDataDir'
& '$InstallPs1' $argStr
"@
    $result = powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output   = ($result -join "`n")
    }
}

function Assert-FileExists {
    param([string]$Path, [string]$Label = '')
    if (Test-Path $Path -PathType Leaf) { return $true }
    $msg = if ($Label) { "$Label — file not found: $Path" } else { "File not found: $Path" }
    throw $msg
}

function Assert-DirExists {
    param([string]$Path, [string]$Label = '')
    if (Test-Path $Path -PathType Container) { return $true }
    $msg = if ($Label) { "$Label — directory not found: $Path" } else { "Directory not found: $Path" }
    throw $msg
}

function Assert-Eq {
    param($Expected, $Actual, [string]$Label = '')
    if ($Expected -eq $Actual) { return $true }
    $msg = "Expected: $Expected`n  Actual:   $Actual"
    if ($Label) { $msg = "$Label`n  $msg" }
    throw $msg
}

function Assert-AllSkillsInstalled {
    param([string]$BaseDir)
    Assert-DirExists $BaseDir "Skills base dir"
    foreach ($skill in $ExpectedSkills) {
        $skillDir  = Join-Path $BaseDir $skill
        $skillFile = Join-Path $skillDir 'SKILL.md'
        Assert-DirExists  $skillDir  "$skill dir"
        Assert-FileExists $skillFile "$skill/SKILL.md"
        $size = (Get-Item $skillFile).Length
        if ($size -lt 100) { throw "$skill/SKILL.md too small ($size bytes)" }
    }
}

function Get-SkillCount {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return 0 }
    return (Get-ChildItem $Dir -Recurse -Filter 'SKILL.md').Count
}

function Get-CommandCount {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return 0 }
    return (Get-ChildItem $Dir -Filter 'sdd-*.md').Count
}

# Run a named test function.  Captures exceptions as failures.
function Invoke-Test {
    param([string]$Name, [scriptblock]$Body)

    $script:TestsRun++
    Write-Host "  $Name ... " -NoNewline

    try {
        $tmpHome    = New-TestDir
        $tmpAppData = New-TestDir
        & $Body -HomeDir $tmpHome -AppDataDir $tmpAppData
        Write-Host 'PASS' -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host 'FAIL' -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor Red
        $script:TestsFailed++
        $script:Failures += $Name
    }
    finally {
        if ($tmpHome)    { Remove-TestDir $tmpHome }
        if ($tmpAppData) { Remove-TestDir $tmpAppData }
    }
}

# ============================================================================
# Tests — Help & Error Handling
# ============================================================================

function Test-HelpFlag {
    param($HomeDir, $AppDataDir)
    $r = Invoke-Installer $HomeDir $AppDataDir @('-Help')
    if ($r.Output -notmatch 'Usage:')        { throw "Help output missing 'Usage:'" }
    if ($r.Output -notmatch 'claude-code')   { throw "Help output missing 'claude-code'" }
    if ($r.Output -notmatch 'all-global')    { throw "Help output missing 'all-global'" }
}

function Test-HelpExitsZero {
    param($HomeDir, $AppDataDir)
    $r = Invoke-Installer $HomeDir $AppDataDir @('-Help')
    Assert-Eq 0 $r.ExitCode '-Help exit code'
}

function Test-InvalidAgentExitsNonZero {
    param($HomeDir, $AppDataDir)
    # -Agent validation is done by ValidateSet; bypass it by passing as a string
    $cmd = "`$env:USERPROFILE='$HomeDir'; `$env:APPDATA='$AppDataDir'; & '$InstallPs1' -Agent nonexistent"
    powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { throw "Expected non-zero exit for invalid agent, got 0" }
}

# ============================================================================
# Tests — Claude Code
# ============================================================================

function Test-InstallClaudeCode {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.claude\skills')
}

function Test-ClaudeCodeSkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    $count = Get-SkillCount (Join-Path $HomeDir '.claude\skills')
    Assert-Eq 13 $count 'Claude Code skill count'
}

# ============================================================================
# Tests — OpenCode
# ============================================================================

function Test-InstallOpenCode {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'opencode') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $AppDataDir 'opencode\skills')
}

function Test-OpenCodeSkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'opencode') | Out-Null
    $count = Get-SkillCount (Join-Path $AppDataDir 'opencode\skills')
    Assert-Eq 13 $count 'OpenCode skill count'
}

function Test-OpenCodeCommands {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'opencode') | Out-Null
    $cmdDir = Join-Path $AppDataDir 'opencode\commands'
    Assert-DirExists $cmdDir 'OpenCode commands dir'
    foreach ($cmd in @('sdd-init', 'sdd-apply', 'sdd-explore', 'sdd-verify',
                        'sdd-archive', 'sdd-new', 'sdd-ff', 'sdd-continue',
                        'sdd-propose', 'sdd-spec', 'sdd-design', 'sdd-tasks')) {
        Assert-FileExists (Join-Path $cmdDir "$cmd.md") $cmd
    }
    $count = Get-CommandCount $cmdDir
    Assert-Eq 12 $count 'OpenCode command count'
}

# ============================================================================
# Tests — Gemini CLI
# ============================================================================

function Test-InstallGeminiCli {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'gemini-cli') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.gemini\skills')
}

function Test-GeminiCliSkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'gemini-cli') | Out-Null
    $count = Get-SkillCount (Join-Path $HomeDir '.gemini\skills')
    Assert-Eq 13 $count 'Gemini CLI skill count'
}

# ============================================================================
# Tests — Codex
# ============================================================================

function Test-InstallCodex {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'codex') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.codex\skills')
}

function Test-CodexSkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'codex') | Out-Null
    $count = Get-SkillCount (Join-Path $HomeDir '.codex\skills')
    Assert-Eq 13 $count 'Codex skill count'
}

# ============================================================================
# Tests — VS Code (project-local .github/skills/)
# ============================================================================

function Test-InstallVsCode {
    param($HomeDir, $AppDataDir)
    $projectDir = Join-Path $HomeDir 'vscode-project'
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    Push-Location $projectDir
    try {
        Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'vscode') | Out-Null
    } finally { Pop-Location }
    Assert-AllSkillsInstalled (Join-Path $projectDir '.github\skills')
}

function Test-VsCodeSkillCount {
    param($HomeDir, $AppDataDir)
    $projectDir = Join-Path $HomeDir 'vscode-project'
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    Push-Location $projectDir
    try {
        Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'vscode') | Out-Null
    } finally { Pop-Location }
    $count = Get-SkillCount (Join-Path $projectDir '.github\skills')
    Assert-Eq 13 $count 'VS Code skill count'
}

# ============================================================================
# Tests — Antigravity
# ============================================================================

function Test-InstallAntigravity {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'antigravity') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.gemini\antigravity\skills')
}

function Test-AntigravitySkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'antigravity') | Out-Null
    $count = Get-SkillCount (Join-Path $HomeDir '.gemini\antigravity\skills')
    Assert-Eq 13 $count 'Antigravity skill count'
}

# ============================================================================
# Tests — Cursor
# ============================================================================

function Test-InstallCursor {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'cursor') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.cursor\skills')
}

function Test-CursorSkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'cursor') | Out-Null
    $count = Get-SkillCount (Join-Path $HomeDir '.cursor\skills')
    Assert-Eq 13 $count 'Cursor skill count'
}

# ============================================================================
# Tests — Project-local
# ============================================================================

function Test-InstallProjectLocal {
    param($HomeDir, $AppDataDir)
    $projectDir = Join-Path $HomeDir 'local-project'
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    Push-Location $projectDir
    try {
        Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'project-local') | Out-Null
    } finally { Pop-Location }
    Assert-AllSkillsInstalled (Join-Path $projectDir 'skills')
}

function Test-ProjectLocalSkillCount {
    param($HomeDir, $AppDataDir)
    $projectDir = Join-Path $HomeDir 'local-project'
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    Push-Location $projectDir
    try {
        Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'project-local') | Out-Null
    } finally { Pop-Location }
    $count = Get-SkillCount (Join-Path $projectDir 'skills')
    Assert-Eq 13 $count 'Project-local skill count'
}

# ============================================================================
# Tests — Custom path
# ============================================================================

function Test-CustomPath {
    param($HomeDir, $AppDataDir)
    $custom = Join-Path $HomeDir 'my-custom-skills'
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'custom', '-Path', $custom) | Out-Null
    Assert-AllSkillsInstalled $custom
}

function Test-CustomPathSkillCount {
    param($HomeDir, $AppDataDir)
    $custom = Join-Path $HomeDir 'my-custom-skills'
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'custom', '-Path', $custom) | Out-Null
    $count = Get-SkillCount $custom
    Assert-Eq 13 $count 'Custom path skill count'
}

function Test-NestedCustomPath {
    param($HomeDir, $AppDataDir)
    $deep = Join-Path $HomeDir 'a\b\c\d\skills'
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'custom', '-Path', $deep) | Out-Null
    Assert-AllSkillsInstalled $deep
}

# ============================================================================
# Tests — All-global
# ============================================================================

function Test-AllGlobal {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'all-global') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.claude\skills')       
    Assert-AllSkillsInstalled (Join-Path $AppDataDir 'opencode\skills')   
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.gemini\skills')       
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.codex\skills')        
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.cursor\skills')       
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.gemini\antigravity\skills')
}

function Test-AllGlobalTotalSkillCount {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'all-global') | Out-Null
    $dirs = @(
        (Join-Path $HomeDir '.claude\skills'),
        (Join-Path $AppDataDir 'opencode\skills'),
        (Join-Path $HomeDir '.gemini\skills'),
        (Join-Path $HomeDir '.codex\skills'),
        (Join-Path $HomeDir '.cursor\skills'),
        (Join-Path $HomeDir '.gemini\antigravity\skills')
    )
    $total = 0
    foreach ($dir in $dirs) {
        $c = Get-SkillCount $dir
        Assert-Eq 13 $c "Expected 13 skills in $dir"
        $total += $c
    }
    Assert-Eq 78 $total '6 targets x 13 skills = 78 total'
}

function Test-AllGlobalOpenCodeCommands {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'all-global') | Out-Null
    $cmdDir = Join-Path $AppDataDir 'opencode\commands'
    Assert-DirExists $cmdDir 'OpenCode commands dir (all-global)'
    $count = Get-CommandCount $cmdDir
    Assert-Eq 12 $count 'OpenCode command count (all-global)'
}

# ============================================================================
# Tests — Idempotency
# ============================================================================

function Test-IdempotentClaudeCode {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.claude\skills')
    $count = Get-SkillCount (Join-Path $HomeDir '.claude\skills')
    Assert-Eq 13 $count 'Claude Code double install count'
}

function Test-IdempotentOpenCode {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'opencode') | Out-Null
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'opencode') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $AppDataDir 'opencode\skills')
    $count = Get-SkillCount (Join-Path $AppDataDir 'opencode\skills')
    Assert-Eq 13 $count 'OpenCode double install count'
    $cmdCount = Get-CommandCount (Join-Path $AppDataDir 'opencode\commands')
    Assert-Eq 12 $cmdCount 'OpenCode double install command count'
}

function Test-IdempotentAllGlobal {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'all-global') | Out-Null
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'all-global') | Out-Null
    $dirs = @(
        (Join-Path $HomeDir '.claude\skills'),
        (Join-Path $AppDataDir 'opencode\skills'),
        (Join-Path $HomeDir '.gemini\skills'),
        (Join-Path $HomeDir '.codex\skills'),
        (Join-Path $HomeDir '.cursor\skills'),
        (Join-Path $HomeDir '.gemini\antigravity\skills')
    )
    foreach ($dir in $dirs) {
        $c = Get-SkillCount $dir
        Assert-Eq 13 $c "Double install: expected 13 in $dir"
    }
}

# ============================================================================
# Tests — Content integrity
# ============================================================================

function Test-SkillContentMatchesSource {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    foreach ($skill in $ExpectedSkills) {
        $src = Join-Path $RepoDir "skills\$skill\SKILL.md"
        $dst = Join-Path $HomeDir ".claude\skills\$skill\SKILL.md"
        $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash $dst -Algorithm SHA256).Hash
        if ($srcHash -ne $dstHash) { throw "Content mismatch for $skill/SKILL.md" }
    }
}

function Test-OpenCodeCommandContentMatchesSource {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'opencode') | Out-Null
    $srcDir = Join-Path $RepoDir 'examples\opencode\commands'
    $dstDir = Join-Path $AppDataDir 'opencode\commands'
    $cmdFiles = Get-ChildItem $srcDir -Filter 'sdd-*.md'
    foreach ($f in $cmdFiles) {
        $dst = Join-Path $dstDir $f.Name
        $srcHash = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash $dst -Algorithm SHA256).Hash
        if ($srcHash -ne $dstHash) { throw "Content mismatch for commands/$($f.Name)" }
    }
}

# ============================================================================
# Tests — Output verification
# ============================================================================

function Test-OutputShowsSkillNames {
    param($HomeDir, $AppDataDir)
    $r = Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code')
    foreach ($skill in $ExpectedSkills) {
        if ($r.Output -notmatch [regex]::Escape($skill)) {
            throw "Output missing skill name: $skill"
        }
    }
}

function Test-OutputShowsInstallCount {
    param($HomeDir, $AppDataDir)
    $r = Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code')
    if ($r.Output -notmatch '13 skills installed') {
        throw "Output missing '13 skills installed'"
    }
}

function Test-OutputShowsNextStep {
    param($HomeDir, $AppDataDir)
    $r = Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code')
    if ($r.Output -notmatch 'Next step') {
        throw "Output missing 'Next step' guidance"
    }
}

function Test-OutputShowsEngramNote {
    param($HomeDir, $AppDataDir)
    $r = Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code')
    if ($r.Output -notmatch 'Engram') {
        throw "Output missing Engram recommendation"
    }
}

# ============================================================================
# Tests — Edge cases
# ============================================================================

function Test-PreExistingCustomSkillNotClobbered {
    param($HomeDir, $AppDataDir)
    $customDir  = Join-Path $HomeDir '.claude\skills\my-custom-skill'
    $customFile = Join-Path $customDir 'SKILL.md'
    New-Item -ItemType Directory -Path $customDir -Force | Out-Null
    Set-Content $customFile 'custom content'
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    Assert-AllSkillsInstalled (Join-Path $HomeDir '.claude\skills')
    Assert-FileExists $customFile 'Custom skill file'
    $actual = Get-Content $customFile -Raw
    if ($actual.Trim() -ne 'custom content') {
        throw "Custom skill content was clobbered (got: $actual)"
    }
}

function Test-OverwriteStaleSkill {
    param($HomeDir, $AppDataDir)
    $staleDir  = Join-Path $HomeDir '.claude\skills\sdd-apply'
    $staleFile = Join-Path $staleDir 'SKILL.md'
    New-Item -ItemType Directory -Path $staleDir -Force | Out-Null
    Set-Content $staleFile 'stale'
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    $content = Get-Content $staleFile -Raw
    if ($content.Trim() -eq 'stale') {
        throw "sdd-apply/SKILL.md was NOT overwritten — still contains stale data"
    }
    $size = (Get-Item $staleFile).Length
    if ($size -lt 100) { throw "sdd-apply/SKILL.md too small after overwrite ($size bytes)" }
}

function Test-SharedFilesInstalled {
    param($HomeDir, $AppDataDir)
    Invoke-Installer $HomeDir $AppDataDir @('-Agent', 'claude-code') | Out-Null
    $sharedDir = Join-Path $HomeDir '.claude\skills\_shared'
    Assert-DirExists $sharedDir '_shared dir'
    Assert-FileExists (Join-Path $sharedDir 'persistence-contract.md') 'persistence-contract.md'
    Assert-FileExists (Join-Path $sharedDir 'engram-convention.md')    'engram-convention.md'
    Assert-FileExists (Join-Path $sharedDir 'openspec-convention.md')  'openspec-convention.md'
}

# ============================================================================
# Run all tests
# ============================================================================

Write-Header

Write-Host 'Help & Error Handling' -ForegroundColor White
Invoke-Test '-Help flag shows usage info'               { param($h,$a) Test-HelpFlag $h $a }
Invoke-Test '-Help exits with code 0'                   { param($h,$a) Test-HelpExitsZero $h $a }
Invoke-Test 'Invalid agent exits non-zero'              { param($h,$a) Test-InvalidAgentExitsNonZero $h $a }
Write-Host ''

Write-Host 'Claude Code' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .claude\skills'  { param($h,$a) Test-InstallClaudeCode $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-ClaudeCodeSkillCount $h $a }
Write-Host ''

Write-Host 'OpenCode' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to opencode\skills' { param($h,$a) Test-InstallOpenCode $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-OpenCodeSkillCount $h $a }
Invoke-Test 'Installs 12 command files'                 { param($h,$a) Test-OpenCodeCommands $h $a }
Write-Host ''

Write-Host 'Gemini CLI' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .gemini\skills'  { param($h,$a) Test-InstallGeminiCli $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-GeminiCliSkillCount $h $a }
Write-Host ''

Write-Host 'Codex' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .codex\skills'   { param($h,$a) Test-InstallCodex $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-CodexSkillCount $h $a }
Write-Host ''

Write-Host 'VS Code (project-local)' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .github\skills'  { param($h,$a) Test-InstallVsCode $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-VsCodeSkillCount $h $a }
Write-Host ''

Write-Host 'Antigravity' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .gemini\antigravity\skills' { param($h,$a) Test-InstallAntigravity $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-AntigravitySkillCount $h $a }
Write-Host ''

Write-Host 'Cursor' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .cursor\skills'  { param($h,$a) Test-InstallCursor $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-CursorSkillCount $h $a }
Write-Host ''

Write-Host 'Project-local' -ForegroundColor White
Invoke-Test 'Installs all 13 skills to .\skills\'       { param($h,$a) Test-InstallProjectLocal $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-ProjectLocalSkillCount $h $a }
Write-Host ''

Write-Host 'Custom path' -ForegroundColor White
Invoke-Test 'Installs to arbitrary custom path'         { param($h,$a) Test-CustomPath $h $a }
Invoke-Test 'Exactly 13 SKILL.md files'                 { param($h,$a) Test-CustomPathSkillCount $h $a }
Invoke-Test 'Handles deeply nested custom path'         { param($h,$a) Test-NestedCustomPath $h $a }
Write-Host ''

Write-Host 'All-global' -ForegroundColor White
Invoke-Test 'Installs to all 6 global targets'          { param($h,$a) Test-AllGlobal $h $a }
Invoke-Test '78 total SKILL.md files (6x13)'            { param($h,$a) Test-AllGlobalTotalSkillCount $h $a }
Invoke-Test 'Also installs OpenCode commands'           { param($h,$a) Test-AllGlobalOpenCodeCommands $h $a }
Write-Host ''

Write-Host 'Idempotency' -ForegroundColor White
Invoke-Test 'Claude Code: double install is safe'       { param($h,$a) Test-IdempotentClaudeCode $h $a }
Invoke-Test 'OpenCode: double install is safe'          { param($h,$a) Test-IdempotentOpenCode $h $a }
Invoke-Test 'All-global: double install is safe'        { param($h,$a) Test-IdempotentAllGlobal $h $a }
Write-Host ''

Write-Host 'Content integrity' -ForegroundColor White
Invoke-Test 'Skills match source files exactly'         { param($h,$a) Test-SkillContentMatchesSource $h $a }
Invoke-Test 'Commands match source files exactly'       { param($h,$a) Test-OpenCodeCommandContentMatchesSource $h $a }
Write-Host ''

Write-Host 'Output verification' -ForegroundColor White
Invoke-Test 'Output lists all skill names'              { param($h,$a) Test-OutputShowsSkillNames $h $a }
Invoke-Test 'Output shows install count'                { param($h,$a) Test-OutputShowsInstallCount $h $a }
Invoke-Test 'Output shows next-step guidance'           { param($h,$a) Test-OutputShowsNextStep $h $a }
Invoke-Test 'Output recommends Engram'                  { param($h,$a) Test-OutputShowsEngramNote $h $a }
Write-Host ''

Write-Host 'Edge cases' -ForegroundColor White
Invoke-Test 'Pre-existing custom skill not clobbered'   { param($h,$a) Test-PreExistingCustomSkillNotClobbered $h $a }
Invoke-Test 'Stale SKILL.md is overwritten'             { param($h,$a) Test-OverwriteStaleSkill $h $a }
Invoke-Test '_shared convention files installed'        { param($h,$a) Test-SharedFilesInstalled $h $a }
Write-Host ''

# ============================================================================
# Summary
# ============================================================================

Write-Host ('=' * 44)
Write-Host "Results: $($script:TestsPassed)/$($script:TestsRun) passed" -ForegroundColor White

if ($script:TestsFailed -gt 0) {
    Write-Host "$($script:TestsFailed) test(s) failed:" -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'All tests passed!' -ForegroundColor Green
Write-Host ''
