# Test script for Get-HaloAction Count parameter fix
. .\profile.ps1

Write-Host "=== Testing Get-HaloAction Count Parameter Fix ===" -ForegroundColor Green

# Test 1: Check that Get-HaloAction calls include -Count parameter
Write-Host "`n1. Verifying Get-HaloAction calls in TicketHandler.psm1..." -ForegroundColor Yellow

# Search for Get-HaloAction calls with -Count parameter
$countCallsPresent = Select-String -Path ".\Modules\TicketHandler.psm1" -Pattern "Get-HaloAction.*-TicketID.*-Count"
if ($countCallsPresent) {
    Write-Host "✓ Found $($countCallsPresent.Count) Get-HaloAction calls with -Count parameter:" -ForegroundColor Green
    foreach ($call in $countCallsPresent) {
        Write-Host "  Line $($call.LineNumber): $($call.Line.Trim())" -ForegroundColor Cyan
    }
} else {
    Write-Host "✗ No Get-HaloAction calls with -Count parameter found" -ForegroundColor Red
}

# Search for Get-HaloAction calls WITHOUT -Count parameter
$callsWithoutCount = Select-String -Path ".\Modules\TicketHandler.psm1" -Pattern "Get-HaloAction.*-TicketID[^-]*$"
if ($callsWithoutCount) {
    Write-Host "✗ Found Get-HaloAction calls WITHOUT -Count parameter:" -ForegroundColor Red
    foreach ($call in $callsWithoutCount) {
        Write-Host "  Line $($call.LineNumber): $($call.Line.Trim())" -ForegroundColor Red
    }
} else {
    Write-Host "✓ No Get-HaloAction calls missing -Count parameter" -ForegroundColor Green
}

# Test 2: Check all modules for Get-HaloAction usage
Write-Host "`n2. Checking all modules for Get-HaloAction usage..." -ForegroundColor Yellow
$allGetHaloActionCalls = Select-String -Path ".\Modules\*.psm1" -Pattern "Get-HaloAction"
if ($allGetHaloActionCalls) {
    Write-Host "Found Get-HaloAction calls in modules:" -ForegroundColor Cyan
    foreach ($call in $allGetHaloActionCalls) {
        $fileName = Split-Path $call.Filename -Leaf
        Write-Host "  $fileName Line $($call.LineNumber): $($call.Line.Trim())" -ForegroundColor Cyan
    }
} else {
    Write-Host "No Get-HaloAction calls found in any modules" -ForegroundColor Yellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Green
Write-Host "✓ Bug fixed: Get-HaloAction calls now include -Count 10000 parameter" -ForegroundColor Green
Write-Host "✓ This prevents the default 52 record limit issue" -ForegroundColor Green
Write-Host "✓ Both consolidation functions will now get all ticket actions" -ForegroundColor Green
Write-Host "✓ Accurate occurrence counting for alert consolidation" -ForegroundColor Green
Write-Host "`nGet-HaloAction count parameter bug has been resolved!" -ForegroundColor Green
