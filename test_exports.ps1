# Test function exports without full module loading
$ticketHandlerContent = Get-Content 'c:\Users\operring\OneDrive - Aegis Computer Maintenance Ltd\Documents\repos\DattoRMM-Alert-HaloPSA\Modules\TicketHandler.psm1' -Raw

# Extract the Export-ModuleMember section more carefully
$exportMatch = [regex]::Match($ticketHandlerContent, "Export-ModuleMember -Function @\((.*?)\)", [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($exportMatch.Success) {
    Write-Host "Export-ModuleMember found!" -ForegroundColor Green
    $exportSection = $exportMatch.Groups[1].Value
    
    # Extract individual function names, handling multiline properly
    $functionMatches = [regex]::Matches($exportSection, "'([^']+)'")
    $exportedFunctions = @()
    foreach ($match in $functionMatches) {
        $exportedFunctions += $match.Groups[1].Value
    }
    
    Write-Host "`nExported functions:" -ForegroundColor Yellow
    $exportedFunctions | ForEach-Object { 
        Write-Host "  - $_" -ForegroundColor Cyan 
    }
    
    Write-Host "`nChecking if consolidation functions are exported..." -ForegroundColor Yellow
    $consolidationFunctions = @('Find-ExistingSecurityAlert', 'Update-ExistingSecurityTicket', 'Test-AlertConsolidation')
    foreach ($func in $consolidationFunctions) {
        if ($func -in $exportedFunctions) {
            Write-Host "✓ $func - EXPORTED" -ForegroundColor Green
        } else {
            Write-Host "✗ $func - NOT EXPORTED" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Export-ModuleMember not found!" -ForegroundColor Red
}
