# Test consolidation debugging
# Test the regex patterns used in the consolidation logic

$testSummaries = @(
    "Device: aegisnm003 raised Alert: Event Log - An account failed to log on. Subject: SEC-001-011-S4",
    "Device: testserver raised Alert: Disk Usage - C: drive usage is above 90%",
    "Device: server01 raised Alert: Patch Monitor - Failure whilst running Patch Policy"
)

Write-Host "Testing alert type extraction patterns:"
Write-Host "=" * 50

foreach ($summary in $testSummaries) {
    Write-Host "`nTesting: $summary"
    
    # Extract device name
    if ($summary -match "Device:\s*([^\s]+)\s+raised Alert") {
        $deviceName = $matches[1]
        Write-Host "Device Name: $deviceName"
    } else {
        Write-Host "Device Name: FAILED TO EXTRACT"
    }
    
    # Test original pattern
    if ($summary -match "raised Alert:\s*-?\s*(.+?)\.?(\s+Subject:|$)") {
        $alertType1 = $matches[1].Trim()
        Write-Host "Original Pattern: '$alertType1'"
    } else {
        Write-Host "Original Pattern: FAILED"
    }
    
    # Test new pattern for category - message format
    if ($summary -match "raised Alert:\s*([^-]+)\s*-\s*(.+?)(\s+Subject:|$)") {
        $alertCategory = $matches[1].Trim()
        $alertMessage = $matches[2].Trim().TrimEnd('.')
        Write-Host "Category: '$alertCategory', Message: '$alertMessage'"
    } elseif ($summary -match "raised Alert:\s*(.+?)(\s+Subject:|$)") {
        $alertType2 = $matches[1].Trim().TrimEnd('.')
        Write-Host "Fallback Pattern: '$alertType2'"
    } else {
        Write-Host "New Pattern: FAILED"
    }
}
