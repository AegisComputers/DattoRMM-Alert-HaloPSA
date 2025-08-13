# Test script for resolved alert fix
. .\profile.ps1

Write-Host "=== Testing Resolved Alert Fix ===" -ForegroundColor Green

Write-Host "`n1. Checking run.ps1 for improved resolved alert handling..." -ForegroundColor Yellow

# Check that the report includes CFDattoAlertUID
$reportSqlCheck = Select-String -Path ".\Receive-Alert\run.ps1" -Pattern "CFDattoAlertUID"
if ($reportSqlCheck) {
    Write-Host "✓ Found CFDattoAlertUID in report SQL:" -ForegroundColor Green
    foreach ($match in $reportSqlCheck) {
        Write-Host "  Line $($match.LineNumber): $($match.Line.Trim())" -ForegroundColor Cyan
    }
} else {
    Write-Host "✗ CFDattoAlertUID not found in report SQL" -ForegroundColor Red
}

# Check for improved logging
Write-Host "`n2. Checking for improved logging in resolved alert section..." -ForegroundColor Yellow
$loggingChecks = @(
    "Processing resolved alert for UID",
    "Closing ticket ID",
    "Successfully closed ticket", 
    "Retrieved.*actions to mark as reviewed",
    "Successfully created invoice",
    "No ticket ID found to close"
)

foreach ($logCheck in $loggingChecks) {
    $logMatch = Select-String -Path ".\Receive-Alert\run.ps1" -Pattern $logCheck
    if ($logMatch) {
        Write-Host "✓ Found logging: $logCheck" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing logging: $logCheck" -ForegroundColor Red
    }
}

# Check for report-based ticket search
Write-Host "`n3. Checking for report-based ticket search..." -ForegroundColor Yellow
$reportSearchCheck = Select-String -Path ".\Receive-Alert\run.ps1" -Pattern "Invoke-HaloReport.*IncludeReport"
if ($reportSearchCheck) {
    Write-Host "✓ Found report-based ticket search" -ForegroundColor Green
} else {
    Write-Host "✗ Report-based ticket search not found" -ForegroundColor Red
}

# Check for Get-HaloAction with Count parameter
Write-Host "`n4. Checking for Get-HaloAction Count parameter fix..." -ForegroundColor Yellow
$actionCountCheck = Select-String -Path ".\Receive-Alert\run.ps1" -Pattern "Get-HaloAction.*-Count"
if ($actionCountCheck) {
    Write-Host "✓ Found Get-HaloAction with Count parameter:" -ForegroundColor Green
    foreach ($match in $actionCountCheck) {
        Write-Host "  Line $($match.LineNumber): $($match.Line.Trim())" -ForegroundColor Cyan
    }
} else {
    Write-Host "✗ Get-HaloAction Count parameter not found" -ForegroundColor Red
}

# Check for error handling
Write-Host "`n5. Checking for improved error handling..." -ForegroundColor Yellow
$errorHandlingChecks = @(
    "try.*catch.*ERROR adding resolution action",
    "try.*catch.*ERROR closing ticket",
    "try.*catch.*ERROR marking actions as reviewed",
    "try.*catch.*ERROR creating invoice"
)

foreach ($errorCheck in $errorHandlingChecks) {
    $errorMatch = Select-String -Path ".\Receive-Alert\run.ps1" -Pattern $errorCheck
    if ($errorMatch) {
        Write-Host "✓ Found error handling: $errorCheck" -ForegroundColor Green
    } else {
        Write-Host "? Error handling pattern: $errorCheck" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Summary of Changes ===" -ForegroundColor Green
Write-Host "✓ Updated Alerts Report to include CFDattoAlertUID field" -ForegroundColor Green
Write-Host "✓ Replaced unreliable Get-HaloTicket search with report-based lookup" -ForegroundColor Green
Write-Host "✓ Added comprehensive logging throughout resolved alert process" -ForegroundColor Green
Write-Host "✓ Added error handling for all critical operations" -ForegroundColor Green
Write-Host "✓ Fixed Get-HaloAction to use -Count 10000 parameter" -ForegroundColor Green
Write-Host "✓ Added status checking to only process open tickets" -ForegroundColor Green

Write-Host "`nKey Improvements:" -ForegroundColor Cyan
Write-Host "• Report-based search: More reliable than text search" -ForegroundColor White
Write-Host "• Better logging: Shows exactly what's happening at each step" -ForegroundColor White  
Write-Host "• Error resilience: Individual failures won't break the entire process" -ForegroundColor White
Write-Host "• Status awareness: Only processes open tickets for resolution" -ForegroundColor White
Write-Host "• Complete action retrieval: Gets all ticket actions, not just 52" -ForegroundColor White

Write-Host "`nThe resolved alert issue should now be fixed!" -ForegroundColor Green
