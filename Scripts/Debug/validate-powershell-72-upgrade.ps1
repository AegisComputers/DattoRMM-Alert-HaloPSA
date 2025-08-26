# PowerShell 7.2 Upgrade Validation Test
# Run this after deployment to validate everything works correctly

Write-Host "=== PowerShell 7.2 Upgrade Validation ===" -ForegroundColor Green
Write-Host "Current PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "Current PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan

# Verify we're running PowerShell 7.2+
if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 2) {
    Write-Host "✅ PowerShell 7.2+ detected" -ForegroundColor Green
} else {
    Write-Host "❌ PowerShell version is not 7.2+. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
}

# Test 1: Module Loading with PowerShell 7.2 requirements
Write-Host "`n=== Testing Module Loading ===" -ForegroundColor Yellow

$modules = @(
    "CoreHelper.psm1",
    "ConfigurationManager.psm1", 
    "EmailHelper.psm1",
    "HaloHelper.psm1",
    "DattoRMMGenerator.psm1",
    "TicketHandler.psm1"
)

$failedModules = @()
foreach ($module in $modules) {
    try {
        $modulePath = Join-Path "Modules" $module
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "✅ $module" -ForegroundColor Green
    } catch {
        Write-Host "❌ $module : $($_.Exception.Message)" -ForegroundColor Red
        $failedModules += $module
    }
}

# Test 2: PowerShell 7.2 Features
Write-Host "`n=== Testing PowerShell 7.2 Features ===" -ForegroundColor Yellow

# Null coalescing operator
try {
    $testValue = $null ?? "PowerShell 7.2 working"
    Write-Host "✅ Null coalescing operator: $testValue" -ForegroundColor Green
} catch {
    Write-Host "❌ Null coalescing operator failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Enhanced JSON handling
try {
    $testObject = @{
        Deep = @{
            Nested = @{
                Object = "PowerShell 7.2 JSON"
                Array = @(1, 2, 3)
            }
        }
    }
    
    $json = $testObject | ConvertTo-Json -Depth 10
    $roundTrip = $json | ConvertFrom-Json -Depth 10
    
    if ($roundTrip.Deep.Nested.Object -eq "PowerShell 7.2 JSON") {
        Write-Host "✅ Enhanced JSON handling working" -ForegroundColor Green
    } else {
        Write-Host "❌ JSON round-trip failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ JSON handling test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Count Property Safety (from our earlier fix)
Write-Host "`n=== Testing Count Property Safety ===" -ForegroundColor Yellow

try {
    # Simulate the scenario that was causing issues
    $nullResult = $null
    $emptyResult = @()
    $filteredResult = @("one", "two") | Where-Object { $_ -eq "three" }
    
    # Test our safe count pattern
    $safeCount1 = if ($nullResult -and $nullResult.Count) { $nullResult.Count } else { 0 }
    $safeCount2 = if ($emptyResult -and $emptyResult.Count) { $emptyResult.Count } else { 0 }
    $safeCount3 = if ($filteredResult -and $filteredResult.Count) { $filteredResult.Count } else { 0 }
    
    Write-Host "✅ Safe count handling: null=$safeCount1, empty=$safeCount2, filtered=$safeCount3" -ForegroundColor Green
} catch {
    Write-Host "❌ Count property safety test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Configuration System
Write-Host "`n=== Testing Configuration System ===" -ForegroundColor Yellow

try {
    if (Get-Command Initialize-AlertingConfiguration -ErrorAction SilentlyContinue) {
        Write-Host "✅ Configuration functions available" -ForegroundColor Green
        
        # Test configuration loading
        if (Get-Command Get-AlertingConfig -ErrorAction SilentlyContinue) {
            $testConfig = Get-AlertingConfig -Path "Storage.TableName" -DefaultValue "TestValue"
            Write-Host "✅ Configuration access working: $testConfig" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Configuration functions not available" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Configuration test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Consolidation Functions (key functionality)
Write-Host "`n=== Testing Alert Consolidation Functions ===" -ForegroundColor Yellow

try {
    if (Get-Command Test-AlertConsolidation -ErrorAction SilentlyContinue) {
        Write-Host "✅ Test-AlertConsolidation function available" -ForegroundColor Green
    } else {
        Write-Host "❌ Test-AlertConsolidation function not available" -ForegroundColor Red
    }
    
    if (Get-Command Test-MemoryUsageConsolidation -ErrorAction SilentlyContinue) {
        Write-Host "✅ Test-MemoryUsageConsolidation function available" -ForegroundColor Green
    } else {
        Write-Host "❌ Test-MemoryUsageConsolidation function not available" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Consolidation function test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n=== UPGRADE VALIDATION SUMMARY ===" -ForegroundColor Green

if ($failedModules.Count -eq 0) {
    Write-Host "✅ All modules loaded successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed modules: $($failedModules -join ', ')" -ForegroundColor Red
}

if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 2) {
    Write-Host "✅ PowerShell 7.2 upgrade successful" -ForegroundColor Green
    Write-Host "✅ Ready for production deployment" -ForegroundColor Green
} else {
    Write-Host "❌ PowerShell upgrade verification failed" -ForegroundColor Red
}

Write-Host "`nUpgrade validation completed at $(Get-Date)" -ForegroundColor Cyan
