using namespace System.Net
using namespace Microsoft.Azure.Cosmos.Table

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Set up error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Function definitions
function Get-DashboardHtml {
    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Datto RMM Alert Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 30px;
            color: white;
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header p {
            font-size: 1.1rem;
            opacity: 0.9;
        }
        
        .controls {
            background: white;
            padding: 20px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            margin-bottom: 30px;
            display: flex;
            flex-wrap: wrap;
            gap: 15px;
            align-items: center;
        }
        
        .refresh-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 600;
            transition: transform 0.2s ease;
            margin-top: 20px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.2s ease;
        }
        
        .alerts-container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 Datto RMM Alert Dashboard</h1>
            <p>Monitor and track all DattoRMM to HaloPSA alert processing</p>
        </div>
        
        <div class="controls">
            <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Data</button>
        </div>
        
        <div class="stats-grid" id="statsGrid">
            <div class="loading">Loading statistics...</div>
        </div>
        
        <div class="alerts-container">
            <div id="alertsContent">
                <div class="loading">Loading alerts...</div>
            </div>
        </div>
    </div>

    <script>
        function refreshData() {
            fetch('api')
                .then(response => response.json())
                .then(data => {
                    console.log('Dashboard data loaded:', data);
                })
                .catch(error => {
                    console.error('Error:', error);
                });
        }
        
        document.addEventListener('DOMContentLoaded', refreshData);
    </script>
</body>
</html>
"@
}

function Get-AlertDataForDashboard {
    param($Request)
    
    return @{
        alerts = @()
        stats = @{
            totalAlerts = 0
            successCount = 0  
            errorCount = 0
            resolvedCount = 0
            avgProcessingTime = 0
        }
    }
}

# Main execution logic
try {
    $action = if ($Request.Params.action) { $Request.Params.action } else { 'view' }
    
    Write-Host "Alert Dashboard - Action: $action"
    
    switch ($action.ToLower()) {
        'api' {
            $alertData = Get-AlertDataForDashboard -Request $Request
            $response = @{
                StatusCode = [HttpStatusCode]::OK
                Headers = @{ 'Content-Type' = 'application/json; charset=utf-8' }
                Body = $alertData | ConvertTo-Json -Depth 10
            }
        }
        default {
            $htmlContent = Get-DashboardHtml
            $response = @{
                StatusCode = [HttpStatusCode]::OK
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                Body = $htmlContent
            }
        }
    }
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $response = @{
        StatusCode = [HttpStatusCode]::InternalServerError
        Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
        Body = "<html><body><h1>Error</h1><p>$($_.Exception.Message)</p></body></html>"
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $response.StatusCode
    Headers = $response.Headers
    Body = $response.Body
})