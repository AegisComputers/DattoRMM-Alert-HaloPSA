# Check HaloAPI parameters
Import-Module HaloAPI

# Get-HaloTicket parameters that might be relevant for active/include searches
$getTicketParams = (Get-Command Get-HaloTicket).Parameters.Keys
$relevantParams = $getTicketParams | Where-Object { $_ -like "*Active*" -or $_ -like "*Include*" -or $_ -like "*Open*" -or $_ -like "*Search*" }

Write-Host "Relevant Get-HaloTicket parameters:" -ForegroundColor Green
$relevantParams | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

Write-Host "`nLooking for the specific parameter that was used..." -ForegroundColor Yellow

# Check the exact parameters being used in our code
$usedParams = @('Search', 'IncludeActive', 'TicketID', 'IncludeNotes')
foreach ($param in $usedParams) {
    if ($param -in $getTicketParams) {
        Write-Host "✓ $param - EXISTS" -ForegroundColor Green
    } else {
        Write-Host "✗ $param - NOT FOUND" -ForegroundColor Red
    }
}
