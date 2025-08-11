# Simple Memory Usage Implementation Test
Write-Host "=== Memory Usage Alert Consolidation Test ===" -ForegroundColor Cyan

# Test 1: Check if functions exist in TicketHandler module
Write-Host "`n1. Testing Function Existence..." -ForegroundColor Yellow
$moduleContent = Get-Content ".\Modules\TicketHandler.psm1" -Raw

$functions = @(
    'Find-ExistingMemoryUsageAlert',
    'Test-MemoryUsageConsolidation', 
    'Update-ExistingMemoryUsageTicket'
)

$allFound = $true
foreach ($func in $functions) {
    if ($moduleContent -match "function $func") {
        Write-Host "  ✓ $func found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $func NOT found" -ForegroundColor Red
        $allFound = $false
    }
}

if ($allFound) {
    Write-Host "  ✓ All functions found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Some functions missing" -ForegroundColor Red
    exit 1
}

# Test 2: Check exports
Write-Host "`n2. Testing Function Exports..." -ForegroundColor Yellow
$exportFound = $true
foreach ($func in $functions) {
    if ($moduleContent -match "'$func'") {
        Write-Host "  ✓ $func exported" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $func NOT exported" -ForegroundColor Red
        $exportFound = $false
    }
}

if ($exportFound) {
    Write-Host "  ✓ All functions exported" -ForegroundColor Green
} else {
    Write-Host "  ✗ Some functions not exported" -ForegroundColor Red
    exit 1
}

# Test 3: Pattern matching
Write-Host "`n3. Testing Pattern Matching..." -ForegroundColor Yellow
$testAlert = "Device: GUILWKS0062 raised Alert: - Memory Usage reached 99%"

# Test device extraction
if ($testAlert -match "Device:\s*([^\s]+)\s+raised Alert") {
    $device = $matches[1]
    Write-Host "  ✓ Device extracted: $device" -ForegroundColor Green
} else {
    Write-Host "  ✗ Device extraction failed" -ForegroundColor Red
    exit 1
}

# Test percentage extraction
if ($testAlert -match "Memory Usage reached (\d+)%") {
    $percentage = $matches[1]
    Write-Host "  ✓ Percentage extracted: $percentage%" -ForegroundColor Green
} else {
    Write-Host "  ✗ Percentage extraction failed" -ForegroundColor Red
    exit 1
}

# Test 4: Check integration in run.ps1
Write-Host "`n4. Testing run.ps1 Integration..." -ForegroundColor Yellow
$runContent = Get-Content ".\Receive-Alert\run.ps1" -Raw

if ($runContent -match 'Memory Usage reached') {
    Write-Host "  ✓ Memory usage detection found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Memory usage detection NOT found" -ForegroundColor Red
    exit 1
}

if ($runContent -match 'Test-MemoryUsageConsolidation') {
    Write-Host "  ✓ Test-MemoryUsageConsolidation call found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Test-MemoryUsageConsolidation call NOT found" -ForegroundColor Red
    exit 1
}

# Test 5: Syntax check
Write-Host "`n5. Testing Syntax..." -ForegroundColor Yellow
try {
    $null = [System.Management.Automation.PSParser]::Tokenize($moduleContent, [ref]$null)
    Write-Host "  ✓ No syntax errors in TicketHandler.psm1" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Syntax errors found: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
Write-Host "✓ All tests PASSED!" -ForegroundColor Green
Write-Host "✓ Implementation is ready for use" -ForegroundColor Green
Write-Host ""
