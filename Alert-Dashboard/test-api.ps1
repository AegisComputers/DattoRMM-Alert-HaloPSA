# Test script for the Alert Dashboard API
param(
    [string]$Action = "api"
)

# Simulate Azure Functions environment
$Request = @{
    Method = 'GET'
    Query = @{
        action = $Action
        days = 5
        status = "all"
        alertType = "all" 
        client = "all"
    }
    Params = @{
        action = $Action
    }
}

$TriggerMetadata = @{}

# Import the dashboard script
. "$PSScriptRoot\run.ps1"

Write-Host "API test completed successfully" -ForegroundColor Green
