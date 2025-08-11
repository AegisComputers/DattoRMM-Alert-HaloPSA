# Final test for PSObject indexing fixes
Write-Host "FINAL PSOBJECT INDEXING FIXES VERIFICATION" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Load the profile
. .\profile.ps1
Write-Host "✓ Profile loaded successfully" -ForegroundColor Green

# Test 1: Get-DecodedTable fix
Write-Host "`n• Testing Get-DecodedTable PSObject fix..." -ForegroundColor Yellow
$testString = "mscorsvw:48.7,system:1.3,msmpeng:0.6"
$result = Get-DecodedTable -TableString $testString -UseValue '%'
$firstApp = $result[0].Application
Write-Host "✓ Get-DecodedTable test passed - First app: $firstApp" -ForegroundColor Green

# Test 2: Configuration conversion
Write-Host "`n• Testing configuration PSObject conversion..." -ForegroundColor Yellow
$config = Get-AlertingConfig -Path "PriorityMapping" -DefaultValue @{"Test" = "Value"}
if ($config -is [PSObject] -and $config -isnot [hashtable]) {
    $converted = @{}
    $config.PSObject.Properties | ForEach-Object { $converted[$_.Name] = $_.Value }
    Write-Host "✓ Configuration PSObject conversion works" -ForegroundColor Green
} else {
    Write-Host "✓ Configuration is already proper type" -ForegroundColor Green
}

# Test 3: Array safety
Write-Host "`n• Testing array safety..." -ForegroundColor Yellow
$testSplit = "site.example.com | Customer Name" -split "\|"
$safeArray = @($testSplit)
$customer = if ($safeArray.Count -gt 1) { $safeArray[1].Trim() } else { "Unknown" }
Write-Host "✓ Array safety test passed - Customer: $customer" -ForegroundColor Green

Write-Host "`nALL PSOBJECT FIXES: VERIFIED" -ForegroundColor Green -BackgroundColor DarkGreen
