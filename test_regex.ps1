# Test regex patterns for alert consolidation
$testSummaries = @(
    'Device: SERVER01 raised Alert: - An account failed to log on. Subject: Login Failure',
    'Device: WORKSTATION-123 raised Alert: Account lockout detected',
    'Device: DC01 raised Alert: - Multiple failed login attempts. Subject: Security Alert',
    'Device: TEST-PC raised Alert: Security audit failure occurred'
)

Write-Host "Testing regex patterns for alert consolidation..." -ForegroundColor Green

foreach ($summary in $testSummaries) {
    Write-Host "`nTesting: $summary" -ForegroundColor Yellow
    
    # Device name extraction
    if ($summary -match 'Device:\s*([^\s]+)\s+raised Alert') {
        $deviceName = $matches[1]
        Write-Host "  Device: $deviceName" -ForegroundColor Cyan
    } else {
        Write-Host "  Device: NOT FOUND" -ForegroundColor Red
    }
    
    # Clear matches
    $matches = $null
    
    # Alert type extraction
    if ($summary -match 'raised Alert:\s*-?\s*(.+?)\.?(\s+Subject:|$)') {
        $alertType = $matches[1].Trim()
        Write-Host "  Alert Type: '$alertType'" -ForegroundColor Cyan
    } else {
        Write-Host "  Alert Type: NOT FOUND" -ForegroundColor Red
    }
    
    # Clear matches for next iteration
    $matches = $null
}

Write-Host "`nRegex testing complete." -ForegroundColor Green
