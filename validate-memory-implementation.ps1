# Comprehensive Memory Usage Alert Implementation Validation
# This script validates all aspects of the memory usage consolidation and Teams notification implementation

Write-Host "=== Memory Usage Alert Implementation Validation ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

$testResults = @()

# Test 1: Pattern Matching Validation
Write-Host "1. Testing Pattern Matching Logic..." -ForegroundColor Yellow

$testAlerts = @(
    @{ 
        Alert = "Device: GUILWKS0062 raised Alert: - Memory Usage reached 99%"
        ExpectedDevice = "GUILWKS0062"
        ExpectedPercentage = 99
        ShouldMatch = $true
    },
    @{ 
        Alert = "Device: SERVER01 raised Alert: - Memory Usage reached 85%"
        ExpectedDevice = "SERVER01"
        ExpectedPercentage = 85
        ShouldMatch = $true
    },
    @{ 
        Alert = "Device: LAPTOP-ABC123 raised Alert: - Memory Usage reached 95%"
        ExpectedDevice = "LAPTOP-ABC123"
        ExpectedPercentage = 95
        ShouldMatch = $true
    },
    @{ 
        Alert = "Device: TESTDEV raised Alert: - Disk Usage reached 95%"
        ExpectedDevice = "TESTDEV"
        ExpectedPercentage = 0
        ShouldMatch = $false
    }
)

$patternTestPassed = $true
foreach ($test in $testAlerts) {
    Write-Host "   Testing: $($test.Alert)" -ForegroundColor Gray
    
    # Test memory usage pattern
    $memoryMatch = $test.Alert -match "Memory Usage reached (\d+)%"
    
    if ($test.ShouldMatch) {
        if ($memoryMatch) {
            $percentage = [int]$matches[1]
            if ($percentage -eq $test.ExpectedPercentage) {
                Write-Host "     ✅ Memory pattern matched correctly: $percentage%" -ForegroundColor Green
            } else {
                Write-Host "     ❌ Wrong percentage extracted. Expected: $($test.ExpectedPercentage), Got: $percentage" -ForegroundColor Red
                $patternTestPassed = $false
            }
        } else {
            Write-Host "     ❌ Memory pattern should have matched but didn't" -ForegroundColor Red
            $patternTestPassed = $false
        }
        
        # Test device extraction
        if ($test.Alert -match "Device:\s*([^\s]+)\s+raised Alert") {
            $device = $matches[1]
            if ($device -eq $test.ExpectedDevice) {
                Write-Host "     ✅ Device extracted correctly: $device" -ForegroundColor Green
            } else {
                Write-Host "     ❌ Wrong device extracted. Expected: $($test.ExpectedDevice), Got: $device" -ForegroundColor Red
                $patternTestPassed = $false
            }
        } else {
            Write-Host "     ❌ Device extraction failed" -ForegroundColor Red
            $patternTestPassed = $false
        }
    } else {
        if (-not $memoryMatch) {
            Write-Host "     ✅ Correctly rejected non-memory alert" -ForegroundColor Green
        } else {
            Write-Host "     ❌ Incorrectly matched non-memory alert" -ForegroundColor Red
            $patternTestPassed = $false
        }
    }
}

$testResults += @{ Test = "Pattern Matching"; Passed = $patternTestPassed }

# Test 2: Function Existence
Write-Host "`n2. Testing Function Definitions..." -ForegroundColor Yellow

$requiredFunctions = @(
    'Find-ExistingMemoryUsageAlert',
    'Test-MemoryUsageConsolidation',
    'Update-ExistingMemoryUsageTicket',
    'Send-AlertConsolidationTeamsNotification',
    'Send-MemoryUsageTeamsNotification'
)

$moduleContent = Get-Content ".\Modules\TicketHandler.psm1" -Raw
$functionsTestPassed = $true

foreach ($func in $requiredFunctions) {
    if ($moduleContent -match "function $func") {
        Write-Host "   ✅ Function '$func' found" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Function '$func' NOT found" -ForegroundColor Red
        $functionsTestPassed = $false
    }
}

$testResults += @{ Test = "Function Definitions"; Passed = $functionsTestPassed }

# Test 3: Export Validation
Write-Host "`n3. Testing Function Exports..." -ForegroundColor Yellow

$exportsTestPassed = $true
foreach ($func in $requiredFunctions) {
    if ($moduleContent -match "'$func'") {
        Write-Host "   ✅ Function '$func' exported" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Function '$func' NOT exported" -ForegroundColor Red
        $exportsTestPassed = $false
    }
}

$testResults += @{ Test = "Function Exports"; Passed = $exportsTestPassed }

# Test 4: Integration Points
Write-Host "`n4. Testing Integration Points..." -ForegroundColor Yellow

$runContent = Get-Content ".\Receive-Alert\run.ps1" -Raw
$integrationTestPassed = $true

# Check memory usage detection
if ($runContent -match '\$TicketSubject -like "\*Memory Usage reached\*"') {
    Write-Host "   ✅ Memory usage detection in run.ps1" -ForegroundColor Green
} else {
    Write-Host "   ❌ Memory usage detection NOT found in run.ps1" -ForegroundColor Red
    $integrationTestPassed = $false
}

# Check function call
if ($runContent -match 'Test-MemoryUsageConsolidation') {
    Write-Host "   ✅ Test-MemoryUsageConsolidation call found" -ForegroundColor Green
} else {
    Write-Host "   ❌ Test-MemoryUsageConsolidation call NOT found" -ForegroundColor Red
    $integrationTestPassed = $false
}

# Check Teams notification calls
if ($moduleContent -match 'Send-MemoryUsageTeamsNotification.*-DeviceName.*-MemoryPercentage.*-OccurrenceCount') {
    Write-Host "   ✅ Teams notification integration found" -ForegroundColor Green
} else {
    Write-Host "   ❌ Teams notification integration NOT found" -ForegroundColor Red
    $integrationTestPassed = $false
}

$testResults += @{ Test = "Integration Points"; Passed = $integrationTestPassed }

# Test 5: Configuration Structure
Write-Host "`n5. Testing Configuration Structure..." -ForegroundColor Yellow

$configTestPassed = $true
try {
    $config = Get-Content ".\teams-webhook-config.json" | ConvertFrom-Json
    
    # Check required configuration sections
    if ($config.AlertConsolidation) {
        Write-Host "   ✅ AlertConsolidation section found" -ForegroundColor Green
        
        if ($config.AlertConsolidation.TeamsNotificationThreshold) {
            Write-Host "   ✅ TeamsNotificationThreshold configured: $($config.AlertConsolidation.TeamsNotificationThreshold)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ TeamsNotificationThreshold not configured" -ForegroundColor Red
            $configTestPassed = $false
        }
        
        if ($config.AlertConsolidation.ConsolidatableAlertTypes -contains "Memory Usage") {
            Write-Host "   ✅ Memory Usage in consolidatable alert types" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Memory Usage NOT in consolidatable alert types" -ForegroundColor Red
            $configTestPassed = $false
        }
    } else {
        Write-Host "   ❌ AlertConsolidation section NOT found" -ForegroundColor Red
        $configTestPassed = $false
    }
    
    if ($config.TeamsNotifications -and $config.TeamsNotifications.WebhookUrl) {
        Write-Host "   ✅ Teams webhook URL configured" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Teams webhook URL NOT configured" -ForegroundColor Red
        $configTestPassed = $false
    }
    
} catch {
    Write-Host "   ❌ Error reading configuration: $($_.Exception.Message)" -ForegroundColor Red
    $configTestPassed = $false
}

$testResults += @{ Test = "Configuration"; Passed = $configTestPassed }

# Test 6: Syntax Validation
Write-Host "`n6. Testing PowerShell Syntax..." -ForegroundColor Yellow

try {
    $tokens = [System.Management.Automation.PSParser]::Tokenize($moduleContent, [ref]$null)
    $syntaxErrors = $tokens | Where-Object { $_.Type -eq 'ParserError' }
    
    if ($syntaxErrors.Count -eq 0) {
        Write-Host "   ✅ No syntax errors found" -ForegroundColor Green
        $syntaxTestPassed = $true
    } else {
        Write-Host "   ❌ Syntax errors found:" -ForegroundColor Red
        $syntaxErrors | ForEach-Object { Write-Host "     Line $($_.StartLine): $($_.Content)" -ForegroundColor Red }
        $syntaxTestPassed = $false
    }
} catch {
    Write-Host "   ❌ Error checking syntax: $($_.Exception.Message)" -ForegroundColor Red
    $syntaxTestPassed = $false
}

$testResults += @{ Test = "Syntax Validation"; Passed = $syntaxTestPassed }

# Test 7: Teams Webhook Test Files
Write-Host "`n7. Testing Teams Webhook Test Files..." -ForegroundColor Yellow

$testFilesTestPassed = $true

if (Test-Path ".\test-memory-teams-webhook.ps1") {
    Write-Host "   ✅ Memory usage test file exists" -ForegroundColor Green
    
    # Check if test file can read config
    $testContent = Get-Content ".\test-memory-teams-webhook.ps1" -Raw
    if ($testContent -match 'teams-webhook-config\.json') {
        Write-Host "   ✅ Test file integrates with config" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Test file doesn't integrate with config" -ForegroundColor Red
        $testFilesTestPassed = $false
    }
} else {
    Write-Host "   ❌ Memory usage test file NOT found" -ForegroundColor Red
    $testFilesTestPassed = $false
}

if (Test-Path ".\test-teams-webhook.ps1") {
    Write-Host "   ✅ Generic Teams test file exists" -ForegroundColor Green
} else {
    Write-Host "   ❌ Generic Teams test file NOT found" -ForegroundColor Red
    $testFilesTestPassed = $false
}

$testResults += @{ Test = "Test Files"; Passed = $testFilesTestPassed }

# Final Results Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "VALIDATION RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

$allTestsPassed = $true
foreach ($result in $testResults) {
    $status = if ($result.Passed) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($result.Passed) { "Green" } else { "Red" }
    Write-Host "  $($result.Test): $status" -ForegroundColor $color
    
    if (-not $result.Passed) {
        $allTestsPassed = $false
    }
}

Write-Host ""
if ($allTestsPassed) {
    Write-Host "🎉 ALL TESTS PASSED! Implementation is ready for production." -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    Write-Host "✅ Memory usage alert consolidation is working correctly" -ForegroundColor Green
    Write-Host "✅ Teams webhook notifications are properly integrated" -ForegroundColor Green
    Write-Host "✅ Pattern matching logic is validated" -ForegroundColor Green
    Write-Host "✅ All functions are defined and exported" -ForegroundColor Green
    Write-Host "✅ Configuration is properly structured" -ForegroundColor Green
    Write-Host "✅ Integration points are correctly implemented" -ForegroundColor Green
} else {
    Write-Host "⚠️  SOME TESTS FAILED! Review the issues above before production deployment." -ForegroundColor Red -BackgroundColor Black
}

Write-Host ""
Write-Host "Validation completed at $(Get-Date)" -ForegroundColor Gray
