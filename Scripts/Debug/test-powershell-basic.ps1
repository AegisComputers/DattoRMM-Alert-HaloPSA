# Simple PowerShell 7.2 Upgrade Validation
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Green

# Test basic functionality
Write-Host "Testing basic PowerShell features..."
$test = $null ?? "default"
Write-Host "Null coalescing works: $test" -ForegroundColor Green

Write-Host "Testing module paths..."
Get-ChildItem -Path ".\Modules" -Filter "*.psm1" | ForEach-Object { 
    Write-Host "Found module: $($_.Name)" -ForegroundColor Cyan 
}
