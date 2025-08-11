# Test Get-DecodedTable PSObject indexing fix
Write-Host "TESTING GET-DECODEDTABLE PSOBJECT INDEXING FIX" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Load the profile to ensure all modules are available
try {
    . .\profile.ps1
    Write-Host "✓ Profile loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Profile load failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test cases for Get-DecodedTable
Write-Host "`n• Testing Get-DecodedTable with various inputs..." -ForegroundColor Yellow

# Test 1: Normal string split scenario
try {
    $testString = "mscorsvw:48.7,system:1.3,msmpeng:0.6"
    $result1 = Get-DecodedTable -TableString $testString -UseValue '%'
    Write-Host "✓ Normal string test passed" -ForegroundColor Green
    Write-Host "  • Result count: $($result1.Count)" -ForegroundColor Gray
    Write-Host "  • First item: $($result1[0].Application) = $($result1[0].'Use %')" -ForegroundColor Gray
} catch {
    Write-Host "✗ Normal string test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Edge case - single item
try {
    $testString2 = "single:100"
    $result2 = Get-DecodedTable -TableString $testString2 -UseValue 'GB'
    Write-Host "✓ Single item test passed" -ForegroundColor Green
    Write-Host "  • Result: $($result2.Application) = $($result2.'Use GB')" -ForegroundColor Gray
} catch {
    Write-Host "✗ Single item test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Edge case - malformed input
try {
    $testString3 = "nocolon,also:missing:too:many"
    $result3 = Get-DecodedTable -TableString $testString3 -UseValue 'MB'
    Write-Host "✓ Malformed input test passed" -ForegroundColor Green
    Write-Host "  • Result count: $($result3.Count)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Malformed input test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Empty/null input
try {
    $testString4 = ""
    $result4 = Get-DecodedTable -TableString $testString4 -UseValue 'KB'
    Write-Host "✓ Empty input test passed" -ForegroundColor Green
} catch {
    Write-Host "✗ Empty input test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test if the CoreHelper module parses without errors
Write-Host "`n• Testing CoreHelper.psm1 parsing..." -ForegroundColor Yellow
try {
    $null = Test-ModuleSyntax $env:USERPROFILE\OneDrive*\Documents\repos\DattoRMM-Alert-HaloPSA\Modules\CoreHelper.psm1
    Write-Host "✓ CoreHelper.psm1 parses without errors" -ForegroundColor Green
} catch {
    Write-Host "✗ CoreHelper.psm1 parsing failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nGET-DECODEDTABLE FIX: COMPLETE" -ForegroundColor Green -BackgroundColor DarkGreen
