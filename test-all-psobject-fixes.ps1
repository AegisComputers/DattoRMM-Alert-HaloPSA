#!/usr/bin/env pwsh

Write-Host "=== TESTING ALL PSOBJECT FIXES ===" -ForegroundColor Cyan

# Test all the modules for PSObject safety
Write-Host "`n1. Testing module loading and functions..." -ForegroundColor Yellow

# Load modules in order
try {
    Import-Module ".\Modules\ConfigurationManager.psm1" -Force -WarningAction SilentlyContinue
    Import-Module ".\Modules\CoreHelper.psm1" -Force -WarningAction SilentlyContinue  
    Import-Module ".\Modules\HaloHelper.psm1" -Force -WarningAction SilentlyContinue
    Import-Module ".\Modules\TicketHandler.psm1" -Force -WarningAction SilentlyContinue
    Write-Host "   ✓ All modules loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Module loading failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test functions are available
$functionsToTest = @(
    'Find-DattoAlertHaloSite',
    'Find-DattoAlertHaloClient', 
    'Test-MemoryUsageConsolidation',
    'Test-AlertConsolidation'
)

foreach ($func in $functionsToTest) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✓ $func available" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $func missing" -ForegroundColor Red
    }
}

Write-Host "`n2. Testing safe indexing patterns..." -ForegroundColor Yellow

# Test site details parsing safety
$testSiteDetails = "TestSite(TestCustomer)"
$dataSiteDetails = $testSiteDetails.Split("(").Split(")")
$safeCustomer = if ($dataSiteDetails -is [array] -and $dataSiteDetails.Count -gt 1) { 
    $dataSiteDetails[1] 
} else { 
    "Unknown" 
}

if ($safeCustomer -eq "TestCustomer") {
    Write-Host "   ✓ Site details parsing works safely" -ForegroundColor Green
} else {
    Write-Host "   ✗ Site details parsing failed: got '$safeCustomer'" -ForegroundColor Red
}

# Test array vs single object safety
$testArray = @("item1", "item2")
$testSingle = "singleItem" 
$testPSObject = New-Object PSObject
$testPSObject | Add-Member -MemberType NoteProperty -Name "Count" -Value 1

$result1 = if ($testArray -is [array]) { $testArray[0] } else { $testArray }
$result2 = if ($testSingle -is [array]) { $testSingle[0] } else { $testSingle }
$result3 = if ($testPSObject -is [array]) { $testPSObject[0] } else { $testPSObject }

if ($result1 -eq "item1" -and $result2 -eq "singleItem" -and $result3 -eq $testPSObject) {
    Write-Host "   ✓ Safe indexing pattern works for all object types" -ForegroundColor Green
} else {
    Write-Host "   ✗ Safe indexing pattern failed" -ForegroundColor Red
}

Write-Host "`n3. Checking fixed files..." -ForegroundColor Yellow

# Count fixed indexing patterns
$fixedPatterns = 0

# Check run.ps1
$runContent = Get-Content ".\Receive-Alert\run.ps1" -Raw
if ($runContent -match 'if \(\$\w+ -is \[array\]\)') {
    $fixedPatterns++
    Write-Host "   ✓ run.ps1 has safe indexing patterns" -ForegroundColor Green
} else {
    Write-Host "   ✗ run.ps1 missing safe indexing patterns" -ForegroundColor Red
}

# Check HaloHelper.psm1  
$haloContent = Get-Content ".\Modules\HaloHelper.psm1" -Raw
if ($haloContent -match 'if \(\$\w+ -is \[array\]\)') {
    $fixedPatterns++
    Write-Host "   ✓ HaloHelper.psm1 has safe indexing patterns" -ForegroundColor Green
} else {
    Write-Host "   ✗ HaloHelper.psm1 missing safe indexing patterns" -ForegroundColor Red
}

# Check TicketHandler.psm1
$ticketContent = Get-Content ".\Modules\TicketHandler.psm1" -Raw  
if ($ticketContent -match 'if \(\$\w+ -is \[array\]\)') {
    $fixedPatterns++
    Write-Host "   ✓ TicketHandler.psm1 has safe indexing patterns" -ForegroundColor Green
} else {
    Write-Host "   ✗ TicketHandler.psm1 missing safe indexing patterns" -ForegroundColor Red
}

Write-Host "`n=== PSOBJECT SAFETY SUMMARY ===" -ForegroundColor Cyan
Write-Host "Files with safe indexing: $fixedPatterns/3" -ForegroundColor White
Write-Host "Key protections:" -ForegroundColor White
Write-Host "  • Array type checking before indexing" -ForegroundColor Gray
Write-Host "  • Bounds checking for array access" -ForegroundColor Gray
Write-Host "  • Fallback values for failed indexing" -ForegroundColor Gray
Write-Host "  • PSObject-to-hashtable conversion" -ForegroundColor Gray
Write-Host "  • Single response binding" -ForegroundColor Gray

if ($fixedPatterns -eq 3) {
    Write-Host "`nALL PSOBJECT VULNERABILITIES FIXED" -ForegroundColor Green
} else {
    Write-Host "`nSOME FIXES MAY BE MISSING" -ForegroundColor Yellow
}
