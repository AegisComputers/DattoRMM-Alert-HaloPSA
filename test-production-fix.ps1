# Test script to verify the production error has been resolved
# This mimics what happens during Azure Function cold start

Write-Host "=== Testing Production Fix ==="
Write-Host "Testing module loading without Unicode/emoji encoding errors..."

try {
    # Test parsing of the TicketHandler module (this was where the Unicode errors occurred)
    Write-Host "1. Testing PowerShell parsing of TicketHandler.psm1..."
    $content = Get-Content "$PSScriptRoot\Modules\TicketHandler.psm1" -Raw
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        Write-Host "   ✅ No parsing errors found!" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Parsing errors found:" -ForegroundColor Red
        foreach ($parseError in $errors) {
            Write-Host "      - Line $($parseError.Extent.StartLineNumber): $($parseError.Message)" -ForegroundColor Red
        }
        return
    }

    Write-Host "2. Testing module import (syntax validation)..."
    
    # Set minimal required environment to avoid initialization errors
    $env:strKey = "test"
    $env:HaloClientID = "test"
    $env:HaloClientSecret = "test"
    $env:HaloURL = "test"
    $env:HaloTicketStatusID = "test"
    $env:HaloCustomAlertTypeField = "test"
    $env:HaloTicketType = "test"
    $env:DattoURL = "test"
    $env:DattoKey = "test"
    $env:DattoSecretKey = "test"
    
    # Import ConfigurationManager first
    Import-Module "$PSScriptRoot\Modules\ConfigurationManager.psm1" -Force -WarningAction SilentlyContinue
    
    # Import TicketHandler (this is where the production error occurred)
    Import-Module "$PSScriptRoot\Modules\TicketHandler.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop
    
    Write-Host "   ✅ Module imported successfully!" -ForegroundColor Green
    
    Write-Host "3. Testing function availability..."
    $function = Get-Command Test-MemoryUsageConsolidation -ErrorAction SilentlyContinue
    if ($function) {
        Write-Host "   ✅ Test-MemoryUsageConsolidation function is available!" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Test-MemoryUsageConsolidation function not found!" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "=== PRODUCTION FIX VERIFIED ==="  -ForegroundColor Green
    Write-Host "The Unicode/emoji encoding errors that caused the critical production error have been resolved." -ForegroundColor Green
    Write-Host "The module can now be loaded successfully during Azure Function cold start." -ForegroundColor Green
    
} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.ToString())" -ForegroundColor Red
} finally {
    # Clean up environment variables
    Remove-Item env:strKey -ErrorAction SilentlyContinue
    Remove-Item env:HaloClientID -ErrorAction SilentlyContinue
    Remove-Item env:HaloClientSecret -ErrorAction SilentlyContinue
    Remove-Item env:HaloURL -ErrorAction SilentlyContinue
    Remove-Item env:HaloTicketStatusID -ErrorAction SilentlyContinue
    Remove-Item env:HaloCustomAlertTypeField -ErrorAction SilentlyContinue
    Remove-Item env:HaloTicketType -ErrorAction SilentlyContinue
    Remove-Item env:DattoURL -ErrorAction SilentlyContinue
    Remove-Item env:DattoKey -ErrorAction SilentlyContinue
    Remove-Item env:DattoSecretKey -ErrorAction SilentlyContinue
}
