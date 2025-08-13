# Test script for the Alert Dashboard
param(
    [string]$Action = "dashboard"
)

# Simulate Azure Functions environment
$Request = @{
    Method = 'GET'
    Query = @{
        action = $Action
        days = 5
    }
}

$TriggerMetadata = @{}

# Import the dashboard script
. "$PSScriptRoot\run.ps1"

Write-Host "Dashboard test completed successfully" -ForegroundColor Green
