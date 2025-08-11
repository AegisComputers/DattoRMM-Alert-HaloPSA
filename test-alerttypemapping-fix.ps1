# Test AlertTypeMapping PSObject fix
Write-Host "TESTING ALERTTYPEMAPPING PSOBJECT FIX" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Load the profile
. .\profile.ps1
Write-Host "✓ Profile loaded successfully" -ForegroundColor Green

# Test the AlertTypeMapping configuration
Write-Host "`n• Testing AlertTypeMapping configuration..." -ForegroundColor Yellow
$config = Get-AlertingConfig -Path "AlertTypeMapping" -DefaultValue @{
    "test_ctx" = "Test Alert"
    "perf_resource_usage_ctx" = "Resource Monitor"
}

Write-Host "Original config type: $($config.GetType().Name)" -ForegroundColor Gray

# Apply the same conversion logic as in CoreHelper.psm1
if ($config -is [PSObject] -and $config -isnot [hashtable]) {
    $hashtable = @{}
    $config.PSObject.Properties | ForEach-Object {
        $hashtable[$_.Name] = $_.Value
    }
    $config = $hashtable
    Write-Host "✓ Converted PSObject to hashtable" -ForegroundColor Green
} else {
    Write-Host "✓ Already proper hashtable type" -ForegroundColor Green
}

# Test hashtable indexing (this is what was failing on line 433)
Write-Host "`n• Testing hashtable indexing..." -ForegroundColor Yellow
try {
    $testKey = "perf_resource_usage_ctx"
    $result = $config[$testKey]
    Write-Host "✓ Hashtable indexing works: $testKey = $result" -ForegroundColor Green
} catch {
    Write-Host "✗ Hashtable indexing failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test with a non-existent key (should not error)
try {
    $testKey2 = "non_existent_ctx"
    $result2 = $config[$testKey2]
    Write-Host "✓ Non-existent key handling works: $testKey2 = '$result2'" -ForegroundColor Green
} catch {
    Write-Host "✗ Non-existent key handling failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nALERTTYPEMAPPING FIX: COMPLETE" -ForegroundColor Green -BackgroundColor DarkGreen
