# PowerShell 7.2 Upgrade Validation Script
# This script tests key functionality before and after the upgrade

param(
    [switch]$PreUpgrade,
    [switch]$PostUpgrade
)

Write-Host "=== PowerShell 7.2 Upgrade Validation Script ===" -ForegroundColor Green
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Cyan
Write-Host "Current Date: $(Get-Date)" -ForegroundColor Cyan

if ($PreUpgrade) {
    Write-Host "`n=== PRE-UPGRADE VALIDATION ===" -ForegroundColor Yellow
} elseif ($PostUpgrade) {
    Write-Host "`n=== POST-UPGRADE VALIDATION ===" -ForegroundColor Yellow
} else {
    Write-Host "`n=== GENERAL VALIDATION ===" -ForegroundColor Yellow
}

# Test 1: Module Loading
Write-Host "`n1. Testing Module Loading..." -ForegroundColor Cyan
$moduleTests = @(
    "CoreHelper.psm1",
    "ConfigurationManager.psm1", 
    "EmailHelper.psm1",
    "HaloHelper.psm1",
    "DattoRMMGenerator.psm1",
    "TicketHandler.psm1"
)

foreach ($moduleName in $moduleTests) {
    $moduleFile = Get-ChildItem -Path ".\Modules" -Filter $moduleName -ErrorAction SilentlyContinue
    if ($moduleFile) {
        try {
            Import-Module $moduleFile.FullName -Force -ErrorAction Stop
            Write-Host "  ✓ $moduleName loaded successfully" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ $moduleName failed to load: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ $moduleName not found" -ForegroundColor Red
    }
}

# Test 2: PowerShell 7.2 Specific Features
Write-Host "`n2. Testing PowerShell Features..." -ForegroundColor Cyan

# Test null coalescing (PowerShell 7.0+)
try {
    $testVar = $null
    $result = $testVar ?? "default"
    Write-Host "  ✓ Null coalescing operator works: '$result'" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Null coalescing operator failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test ForEach-Object -Parallel (PowerShell 7.0+)
try {
    $numbers = 1..5
    $results = $numbers | ForEach-Object -Parallel { $_ * 2 } -ThrottleLimit 3
    Write-Host "  ✓ ForEach-Object -Parallel works: [$($results -join ', ')]" -ForegroundColor Green
} catch {
    Write-Host "  ✗ ForEach-Object -Parallel failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test JSON handling with depth
try {
    $testObject = @{
        Level1 = @{
            Level2 = @{
                Level3 = "deep value"
            }
        }
    }
    $json = $testObject | ConvertTo-Json -Depth 10
    $backToObject = $json | ConvertFrom-Json -Depth 10
    Write-Host "  ✓ JSON deep conversion works" -ForegroundColor Green
} catch {
    Write-Host "  ✗ JSON deep conversion failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Error handling patterns
Write-Host "`n3. Testing Error Handling..." -ForegroundColor Cyan

try {
    # Test the Count property safety we fixed
    $nullArray = $null
    $safeCount = if ($nullArray -and $nullArray.Count) { $nullArray.Count } else { 0 }
    Write-Host "  ✓ Safe count handling works: $safeCount" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Safe count handling failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Configuration system
Write-Host "`n4. Testing Configuration System..." -ForegroundColor Cyan

try {
    if (Get-Command Initialize-AlertingConfiguration -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ Configuration functions available" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Configuration functions not available" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Configuration system test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: External Module Dependencies
Write-Host "`n5. Testing External Module Dependencies..." -ForegroundColor Cyan

$externalModules = @(
    @{Name="DattoRMM"; MinVersion="1.0.0.28"},
    @{Name="HaloAPI"; MinVersion="1.16.0"},
    @{Name="Az.Accounts"; MinVersion="3.0.3"},
    @{Name="Az.Storage"; MinVersion="5.1.0"},
    @{Name="AzTable"; MinVersion="2.1.0"}
)

foreach ($module in $externalModules) {
    try {
        $installedModule = Get-Module -ListAvailable -Name $module.Name | 
                          Sort-Object Version -Descending | 
                          Select-Object -First 1
        
        if ($installedModule) {
            if ([Version]$installedModule.Version -ge [Version]$module.MinVersion) {
                Write-Host "  ✓ $($module.Name) available: v$($installedModule.Version)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ $($module.Name) version too old: v$($installedModule.Version) (need $($module.MinVersion)+)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✗ $($module.Name) not installed" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Error checking $($module.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 6: Azure Functions compatibility
Write-Host "`n6. Testing Azure Functions Compatibility..." -ForegroundColor Cyan

try {
    # Test that we can read environment variables the way Azure Functions provides them
    $testEnvVar = $env:TEMP
    if ($testEnvVar) {
        Write-Host "  ✓ Environment variable access works" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Environment variable access may have issues" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ Environment variable test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== VALIDATION COMPLETE ===" -ForegroundColor Green
Write-Host "Check the results above for any issues that need to be addressed." -ForegroundColor White
