# Debug script to test Halo API ticket retrieval and status information
# This will help us understand why status_name is empty

Write-Host "Testing Halo API ticket retrieval..." -ForegroundColor Yellow

# Test the same search that's failing
$deviceName = "aadc0001"
Write-Host "Searching for tickets from device: $deviceName"

try {
    # Test different search methods
    Write-Host "`n1. Testing search with -OpenOnly -FullObjects" -ForegroundColor Cyan
    $searchResults1 = Get-HaloTicket -Search "Device: $deviceName" -OpenOnly -FullObjects
    Write-Host "Found $($searchResults1.Count) tickets"
    
    if ($searchResults1.Count -gt 0) {
        $firstTicket = $searchResults1[0]
        Write-Host "First ticket properties:"
        Write-Host "  ID: $($firstTicket.id)"
        Write-Host "  Summary: $($firstTicket.summary)"
        Write-Host "  Status Name: '$($firstTicket.status_name)'"
        Write-Host "  Status ID: '$($firstTicket.status_id)'"
        Write-Host "  Date Occurred: '$($firstTicket.dateoccured)'"
        
        # Test getting full details for this ticket
        Write-Host "`n2. Testing full details retrieval for ticket $($firstTicket.id)" -ForegroundColor Cyan
        $fullTicket = Get-HaloTicket -TicketID $firstTicket.id -IncludeDetails -FullObjects
        Write-Host "Full ticket properties:"
        Write-Host "  ID: $($fullTicket.id)"
        Write-Host "  Status Name: '$($fullTicket.status_name)'"
        Write-Host "  Status ID: '$($fullTicket.status_id)'"
        Write-Host "  Date Occurred: '$($fullTicket.dateoccured)'"
        
        # Show all available properties to see what we have
        Write-Host "`n3. All properties on search result:" -ForegroundColor Cyan
        $firstTicket | Get-Member -MemberType Property | Select-Object Name | ForEach-Object { 
            $propName = $_.Name
            $propValue = $firstTicket.$propName
            if ($propName -like "*status*" -or $propName -like "*date*") {
                Write-Host "  $propName : '$propValue'"
            }
        }
    }
    
    # Test without OpenOnly to see if that's the issue
    Write-Host "`n4. Testing search without -OpenOnly" -ForegroundColor Cyan
    $searchResults2 = Get-HaloTicket -Search "Device: $deviceName" -FullObjects
    Write-Host "Found $($searchResults2.Count) tickets"
    
    if ($searchResults2.Count -gt 0) {
        $firstTicket2 = $searchResults2[0]
        Write-Host "First ticket without OpenOnly:"
        Write-Host "  ID: $($firstTicket2.id)"
        Write-Host "  Status Name: '$($firstTicket2.status_name)'"
        Write-Host "  Status ID: '$($firstTicket2.status_id)'"
    }
    
} catch {
    Write-Error "Error during testing: $($_.Exception.Message)"
}
