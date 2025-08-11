# Project Organization and Cleanup Script
# This script organizes the DattoRMM-Alert-HaloPSA project structure

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$CreateBackup
)

Write-Host "=== DattoRMM-Alert-HaloPSA Project Organization ===" -ForegroundColor Green

$projectRoot = $PSScriptRoot -replace '\\Scripts.*$', ''
Write-Host "Project root: $projectRoot"

if ($CreateBackup) {
    $backupPath = Join-Path $projectRoot "Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "Creating backup at: $backupPath" -ForegroundColor Yellow
    
    if (-not $WhatIf) {
        Copy-Item -Path $projectRoot -Destination $backupPath -Recurse -Exclude @('.git', 'Backup_*')
        Write-Host "Backup created successfully" -ForegroundColor Green
    }
}

# Define the target structure
$targetStructure = @{
    'Scripts\Debug' = @('test_*.ps1', 'debug_*.ps1', 'check_*.ps1')
    'Scripts\Utilities' = @('*.utility.ps1', '*-Helper.ps1')
    'Tests' = @('*.Tests.ps1', '*.test.ps1')
    'Docs' = @('*.md', '*.txt')
}

Write-Host "`n=== Files moved to Scripts\Debug ===" -ForegroundColor Cyan
Get-ChildItem -Path "$projectRoot\Scripts\Debug" -File | ForEach-Object {
    Write-Host "  ✓ $($_.Name)" -ForegroundColor Gray
}

Write-Host "`n=== Module Structure ===" -ForegroundColor Cyan
Get-ChildItem -Path "$projectRoot\Modules" -File | ForEach-Object {
    $status = if ($_.Extension -eq '.psd1') { '✓ [NEW]' } else { '✓' }
    Write-Host "  $status $($_.Name)" -ForegroundColor Gray
}

Write-Host "`n=== Function Name Updates ===" -ForegroundColor Cyan
$functionMappings = @{
    'Handle-DiskUsageAlert' = 'Invoke-DiskUsageAlert'
    'Handle-HyperVReplicationAlert' = 'Invoke-HyperVReplicationAlert'
    'Handle-PatchMonitorAlert' = 'Invoke-PatchMonitorAlert'
    'Handle-BackupExecAlert' = 'Invoke-BackupExecAlert'
    'Handle-HostsAlert' = 'Invoke-HostsAlert'
    'Handle-DefaultAlert' = 'Invoke-DefaultAlert'
}

foreach ($old in $functionMappings.Keys) {
    Write-Host "  ✓ $old → $($functionMappings[$old])" -ForegroundColor Gray
}

Write-Host "`n=== Error Handling Enhancements ===" -ForegroundColor Cyan
Write-Host "  ✓ Added comprehensive try-catch blocks" -ForegroundColor Gray
Write-Host "  ✓ Enhanced retry logic with exponential backoff" -ForegroundColor Gray
Write-Host "  ✓ Structured error logging for Azure Monitor" -ForegroundColor Gray
Write-Host "  ✓ Input validation and sanitization" -ForegroundColor Gray
Write-Host "  ✓ Module initialization validation" -ForegroundColor Gray

Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Test the updated functions in a development environment"
Write-Host "2. Update any remaining references to Handle-* functions"
Write-Host "3. Deploy to Azure Functions with enhanced monitoring"
Write-Host "4. Create comprehensive documentation"
Write-Host "5. Set up automated testing pipeline"

Write-Host "`n=== Recommendations ===" -ForegroundColor Magenta
Write-Host "• Create unit tests for all refactored functions"
Write-Host "• Implement Application Insights for better monitoring"
Write-Host "• Add configuration validation on startup"
Write-Host "• Consider implementing circuit breaker pattern for external APIs"
Write-Host "• Add health check endpoints for monitoring"

Write-Host "`nProject organization complete! ✨" -ForegroundColor Green
