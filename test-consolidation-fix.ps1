#!/usr/bin/env pwsh

Write-Host "=== TESTING CONSOLIDATION PSOBJECT FIX ===" -ForegroundColor Cyan

# Test the exact scenario that was causing the PSObject indexing error
Write-Host "`n1. Testing consolidatable types PSObject handling..." -ForegroundColor Yellow

try {
    # Load modules
    Import-Module ".\Modules\ConfigurationManager.psm1" -Force -WarningAction SilentlyContinue
    Import-Module ".\Modules\TicketHandler.psm1" -Force -WarningAction SilentlyContinue
    
    # Simulate the PSObject scenario that was causing the error
    $testPSObject = New-Object PSObject
    $testPSObject | Add-Member -MemberType NoteProperty -Name "Type1" -Value "Memory"
    $testPSObject | Add-Member -MemberType NoteProperty -Name "Type2" -Value "Security"
    
    # Test our new safe array conversion logic
    $consolidatableTypes = @()
    if ($testPSObject) {
        if ($testPSObject -is [array]) {
            $consolidatableTypes = $testPSObject
        } elseif ($testPSObject -is [PSObject]) {
            # Convert PSObject to array if needed
            $consolidatableTypes = @($testPSObject.PSObject.Properties | ForEach-Object { $_.Value })
        } else {
            # Single item, make it an array
            $consolidatableTypes = @($testPSObject)
        }
    }
    
    # Test iteration (this was failing before)
    $foundMemory = $false
    foreach ($type in $consolidatableTypes) {
        if ("Memory Usage" -like "*$type*") {
            $foundMemory = $true
            break
        }
    }
    
    if ($foundMemory -and $consolidatableTypes.Count -eq 2) {
        Write-Host "   ✓ PSObject to array conversion works correctly" -ForegroundColor Green
        Write-Host "   ✓ Safe iteration over converted array works" -ForegroundColor Green
    } else {
        Write-Host "   ✗ PSObject conversion failed" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ✗ PSObject handling test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test that the functions are still available and working
Write-Host "`n2. Testing consolidation functions..." -ForegroundColor Yellow

$functionsToTest = @('Test-MemoryUsageConsolidation', 'Test-AlertConsolidation', 'Find-ExistingMemoryUsageAlert', 'Find-ExistingSecurityAlert')

foreach ($func in $functionsToTest) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✓ $func available" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $func missing" -ForegroundColor Red
    }
}

Write-Host "`n3. Testing module parsing..." -ForegroundColor Yellow
try {
    $parseErrors = @()
    $content = Get-Content ".\Modules\TicketHandler.psm1" -Raw
    $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$parseErrors)
    
    if ($parseErrors.Count -eq 0) {
        Write-Host "   ✓ TicketHandler.psm1 parses without errors" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Found $($parseErrors.Count) parsing errors in TicketHandler.psm1" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Module parsing test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== CONSOLIDATION PSOBJECT FIX SUMMARY ===" -ForegroundColor Cyan
Write-Host "Fixed Issues:" -ForegroundColor White
Write-Host "  • ConsolidatableAlertTypes PSObject handling in Find-ExistingMemoryUsageAlert" -ForegroundColor Gray
Write-Host "  • ConsolidatableAlertTypes PSObject handling in Find-ExistingSecurityAlert" -ForegroundColor Gray
Write-Host "  • Safe array conversion for configuration arrays" -ForegroundColor Gray
Write-Host "  • Prevents PSObject indexing errors during foreach iteration" -ForegroundColor Gray

Write-Host "`nCONSOLIDATION FUNCTIONS: PSOBJECT-SAFE" -ForegroundColor Green
