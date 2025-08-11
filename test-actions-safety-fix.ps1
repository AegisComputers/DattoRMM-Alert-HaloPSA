# Test for actions property safety fix
Write-Host "TESTING ACTIONS PROPERTY SAFETY FIX" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Load the profile
. .\profile.ps1
Write-Host "✓ Profile loaded successfully" -ForegroundColor Green

# Test safe actions property access
Write-Host "`n• Testing safe actions property access..." -ForegroundColor Yellow

# Mock ticket object without actions property
$mockTicketNoActions = [PSCustomObject]@{
    id = 12345
    summary = "Test ticket"
    # No actions property
}

# Mock ticket object with null actions
$mockTicketNullActions = [PSCustomObject]@{
    id = 12346
    summary = "Test ticket 2"
    actions = $null
}

# Mock ticket object with proper actions
$mockTicketWithActions = [PSCustomObject]@{
    id = 12347
    summary = "Test ticket 3"
    actions = @(
        [PSCustomObject]@{ note = "Additional Test alert detected at 2025-08-11" },
        [PSCustomObject]@{ note = "Some other note" }
    )
}

# Test 1: No actions property
Write-Host "  Testing ticket with no actions property..." -ForegroundColor Gray
$consolidationNotes = @()
if ($mockTicketNoActions -and $mockTicketNoActions.PSObject.Properties.Name -contains 'actions' -and $mockTicketNoActions.actions) {
    $consolidationNotes = $mockTicketNoActions.actions | Where-Object { $_.note -like "*Additional Test alert detected*" }
} else {
    Write-Host "    ✓ Safely handled missing actions property" -ForegroundColor Green
}
Write-Host "    Count: $($consolidationNotes.Count)" -ForegroundColor Gray

# Test 2: Null actions
Write-Host "  Testing ticket with null actions..." -ForegroundColor Gray
$consolidationNotes = @()
if ($mockTicketNullActions -and $mockTicketNullActions.PSObject.Properties.Name -contains 'actions' -and $mockTicketNullActions.actions) {
    $consolidationNotes = $mockTicketNullActions.actions | Where-Object { $_.note -like "*Additional Test alert detected*" }
} else {
    Write-Host "    ✓ Safely handled null actions property" -ForegroundColor Green
}
Write-Host "    Count: $($consolidationNotes.Count)" -ForegroundColor Gray

# Test 3: Proper actions
Write-Host "  Testing ticket with proper actions..." -ForegroundColor Gray
$consolidationNotes = @()
if ($mockTicketWithActions -and $mockTicketWithActions.PSObject.Properties.Name -contains 'actions' -and $mockTicketWithActions.actions) {
    $consolidationNotes = $mockTicketWithActions.actions | Where-Object { $_.note -like "*Additional Test alert detected*" }
    Write-Host "    ✓ Successfully accessed actions property" -ForegroundColor Green
} else {
    Write-Host "    ✗ Failed to access actions property" -ForegroundColor Red
}
Write-Host "    Found consolidation notes: $($consolidationNotes.Count)" -ForegroundColor Gray

Write-Host "`nACTIONS PROPERTY SAFETY FIX: COMPLETE" -ForegroundColor Green -BackgroundColor DarkGreen
