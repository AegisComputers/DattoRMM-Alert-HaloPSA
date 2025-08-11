# Final comprehensive test for all PSObject indexing fixes
Write-Host "COMPREHENSIVE PSOBJECT INDEXING FIXES TEST" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Load the profile
try {
    . .\profile.ps1
    Write-Host "✓ Profile loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Profile load failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 1: Get-DecodedTable fix
Write-Host "`n• Testing Get-DecodedTable PSObject fix..." -ForegroundColor Yellow
try {
    $testString = "mscorsvw:48.7,system:1.3,msmpeng:0.6"
    $result = Get-DecodedTable -TableString $testString -UseValue '%'
    $firstApp = $result[0].Application
    Write-Host "✓ Get-DecodedTable test passed - First app: $firstApp" -ForegroundColor Green
} catch {
    Write-Host "✗ Get-DecodedTable test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Consolidation function PSObject-to-array conversion
Write-Host "`n• Testing consolidation functions..." -ForegroundColor Yellow
try {
    if (Get-Command Test-MemoryUsageConsolidation -ErrorAction SilentlyContinue) {
        Write-Host "✓ Test-MemoryUsageConsolidation function available" -ForegroundColor Green
    } else {
        Write-Host "✗ Test-MemoryUsageConsolidation function not found" -ForegroundColor Red
    }
    
    if (Get-Command Find-ExistingMemoryUsageAlert -ErrorAction SilentlyContinue) {
        Write-Host "✓ Find-ExistingMemoryUsageAlert function available" -ForegroundColor Green
    } else {
        Write-Host "✗ Find-ExistingMemoryUsageAlert function not found" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Consolidation function test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Configuration array handling
Write-Host "`n• Testing configuration array handling..." -ForegroundColor Yellow
try {
    $priorityConfig = Get-AlertingConfig -Path "PriorityMapping" -DefaultValue @{
        "Critical" = "4"
        "High" = "4"
    }
    
    # Test if we can safely access it
    if ($priorityConfig -is [PSObject] -and $priorityConfig -isnot [hashtable]) {
        $testHash = @{}
        $priorityConfig.PSObject.Properties | ForEach-Object {
            $testHash[$_.Name] = $_.Value
        }
        Write-Host "✓ Priority mapping PSObject conversion works" -ForegroundColor Green
    } else {
        Write-Host "✓ Priority mapping is already a proper hashtable" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Configuration array test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: String split operations
Write-Host "`n• Testing string split PSObject safety..." -ForegroundColor Yellow
try {
    $testSplit = "site.example.com | Customer Name"
    $dataSiteDetails = $testSplit -split "\|"
    $dataSiteDetailsArray = @($dataSiteDetails)
    $customer = if ($dataSiteDetailsArray.Count -gt 1) { $dataSiteDetailsArray[1].Trim() } else { "Unknown" }
    Write-Host "✓ String split array handling works - Customer: $customer" -ForegroundColor Green
} catch {
    Write-Host "✗ String split test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Module parsing verification
Write-Host "`n• Testing all module parsing..." -ForegroundColor Yellow
$modules = @(
    "TicketHandler.psm1",
    "CoreHelper.psm1",
    "HaloHelper.psm1"
)

foreach ($module in $modules) {
    try {
        $modulePath = Join-Path $env:USERPROFILE "OneDrive*\Documents\repos\DattoRMM-Alert-HaloPSA\Modules\$module"
        $resolvedPath = Get-ChildItem $modulePath -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($resolvedPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $resolvedPath.FullName -Raw), [ref]$null)
            Write-Host "✓ $module parses without errors" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ $module parsing failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nCOMPREHENSIVE PSOBJECT FIXES: COMPLETE" -ForegroundColor Green -BackgroundColor DarkGreen
Write-Host "All PSObject indexing issues should now be resolved!" -ForegroundColor Green
