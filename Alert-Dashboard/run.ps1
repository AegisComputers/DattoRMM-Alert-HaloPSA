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
        
        .control-group {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }
        
        .control-group label {
            font-weight: 600;
            color: #555;
            font-size: 0.9rem;
        }
        
        .control-group select {
            padding: 8px 12px;
            border: 2px solid #e1e5e9;
            border-radius: 6px;
            font-size: 0.95rem;
            transition: border-color 0.2s ease;
        }
        
        .control-group select:focus {
            outline: none;
            border-color: #667eea;
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
        }
        
        .refresh-btn:hover {
            transform: translateY(-2px);
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
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-value {
            font-size: 2.5rem;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #666;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .stat-card.success .stat-value { color: #28a745; }
        .stat-card.error .stat-value { color: #dc3545; }
        .stat-card.warning .stat-value { color: #ffc107; }
        .stat-card.info .stat-value { color: #17a2b8; }
        
        .alerts-container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .alerts-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            font-size: 1.2rem;
            font-weight: 600;
        }
        
        .alerts-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .alerts-table th,
        .alerts-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        
        .alerts-table th {
            background-color: #f8f9fa;
            font-weight: 600;
            color: #555;
        }
        
        .alerts-table tbody tr:hover {
            background-color: #f5f5f5;
        }
        
        .status-badge {
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-success {
            background-color: #d4edda;
            color: #155724;
        }
        
        .status-error {
            background-color: #f8d7da;
            color: #721c24;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        
        .error-message {
            background-color: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 6px;
            margin: 20px 0;
            border: 1px solid #f5c6cb;
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
            <div class="control-group">
                <label for="days">Time Period</label>
                <select id="days">
                    <option value="1">Last 24 Hours</option>
                    <option value="3">Last 3 Days</option>
                    <option value="5" selected>Last 5 Days</option>
                    <option value="7">Last 7 Days</option>
                    <option value="14">Last 14 Days</option>
                    <option value="30">Last 30 Days</option>
                </select>
            </div>
            
            <div class="control-group">
                <label for="statusFilter">Status</label>
                <select id="statusFilter">
                    <option value="all">All Status</option>
                    <option value="success">Success Only</option>
                    <option value="error">Errors Only</option>
                </select>
            </div>
            
            <div class="control-group">
                <label for="alertTypeFilter">Alert Type</label>
                <select id="alertTypeFilter">
                    <option value="all">All Types</option>
                    <option value="Memory High">Memory Alerts</option>
                    <option value="CPU High">CPU Alerts</option>
                    <option value="Host File Changes">Host File Changes</option>
                    <option value="Service Down">Service Down</option>
                </select>
            </div>
            
            <div class="control-group">
                <label for="clientFilter">Client</label>
                <select id="clientFilter">
                    <option value="all">All Clients</option>
                </select>
            </div>
            
            <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Data</button>
        </div>
        
        <div class="stats-grid" id="statsGrid">
            <div class="loading">Loading statistics...</div>
        </div>
        
        <div class="alerts-container">
            <div class="alerts-header">
                <span id="alertsTitle">Recent Alerts</span>
                <span id="lastUpdated" style="float: right; font-size: 0.9rem; opacity: 0.8;"></span>
            </div>
            <div id="alertsContent">
                <div class="loading">Loading alerts...</div>
            </div>
        </div>
    </div>

    <script>
        // Initialize dashboard
        document.addEventListener('DOMContentLoaded', function() {
            refreshData();
        });
        
        function refreshData() {
            const days = document.getElementById('days').value;
            const statusFilter = document.getElementById('statusFilter').value;
            const alertTypeFilter = document.getElementById('alertTypeFilter').value;
            const clientFilter = document.getElementById('clientFilter').value;
            
            // Update loading state
            document.getElementById('alertsContent').innerHTML = '<div class="loading">Loading alerts...</div>';
            document.getElementById('statsGrid').innerHTML = '<div class="loading">Loading statistics...</div>';
            
            // Build API URL
            const params = new URLSearchParams({
                days: days,
                status: statusFilter,
                alertType: alertTypeFilter,
                client: clientFilter
            });
            
            console.log('Fetching data with params:', params.toString());
            // Use the correct relative URL for the API endpoint
            const apiUrl = window.location.pathname.replace('/view', '/api') + '?' + params.toString();
            console.log('API URL:', apiUrl);
            console.log('Current pathname:', window.location.pathname);
            
            fetch(apiUrl)
                .then(response => {
                    console.log('Response status:', response.status);
                    console.log('Response headers:', response.headers.get('content-type'));
                    console.log('Response URL:', response.url);
                    
                    // Check if we're getting HTML instead of JSON
                    const contentType = response.headers.get('content-type');
                    if (contentType && contentType.includes('text/html')) {
                        console.error('Received HTML instead of JSON - API route not working');
                        throw new Error('API endpoint returned HTML instead of JSON');
                    }
                    
                    if (!response.ok) {
                        throw new Error('HTTP error! status: ' + response.status);
                    }
                    return response.json();
                })
                .then(data => {
                    console.log('Received data:', data);
                    updateStats(data.stats);
                    updateAlertsTable(data.alerts);
                    updateClientFilter(data.alerts);
                    updateLastUpdated();
                })
                .catch(error => {
                    console.error('Error fetching data:', error);
                    document.getElementById('alertsContent').innerHTML = 
                        '<div class="error-message">Failed to load alert data. Please try again.</div>';
                    document.getElementById('statsGrid').innerHTML = 
                        '<div class="error-message">Failed to load statistics.</div>';
                });
        }
        
        function updateStats(stats) {
            const successRate = stats.totalAlerts > 0 ? Math.round((stats.successCount / stats.totalAlerts) * 100) : 0;
            
            const statsHtml = 
                '<div class="stat-card info">' +
                    '<div class="stat-value">' + stats.totalAlerts + '</div>' +
                    '<div class="stat-label">Total Alerts</div>' +
                '</div>' +
                '<div class="stat-card success">' +
                    '<div class="stat-value">' + stats.successCount + '</div>' +
                    '<div class="stat-label">Successful</div>' +
                '</div>' +
                '<div class="stat-card error">' +
                    '<div class="stat-value">' + stats.errorCount + '</div>' +
                    '<div class="stat-label">Errors</div>' +
                '</div>' +
                '<div class="stat-card warning">' +
                    '<div class="stat-value">' + stats.resolvedCount + '</div>' +
                    '<div class="stat-label">Resolved</div>' +
                '</div>' +
                '<div class="stat-card info">' +
                    '<div class="stat-value">' + successRate + '%</div>' +
                    '<div class="stat-label">Success Rate</div>' +
                '</div>' +
                '<div class="stat-card info">' +
                    '<div class="stat-value">' + stats.avgProcessingTime + 's</div>' +
                    '<div class="stat-label">Avg Processing Time</div>' +
                '</div>';
            
            document.getElementById('statsGrid').innerHTML = statsHtml;
        }
        
        function updateAlertsTable(alerts) {
            if (alerts.length === 0) {
                document.getElementById('alertsContent').innerHTML = 
                    '<div class="loading">No alerts found for the selected criteria.</div>';
                return;
            }
            
            let tableHtml = 
                '<table class="alerts-table">' +
                    '<thead>' +
                        '<tr>' +
                            '<th>Timestamp</th>' +
                            '<th>Status</th>' +
                            '<th>Client</th>' +
                            '<th>Device</th>' +
                            '<th>Alert Type</th>' +
                            '<th>Summary</th>' +
                            '<th>Ticket ID</th>' +
                            '<th>Processing Time</th>' +
                        '</tr>' +
                    '</thead>' +
                    '<tbody>';
            
            alerts.forEach(alert => {
                const statusClass = alert.status === 'success' ? 'status-success' : 'status-error';
                const timestamp = new Date(alert.timestamp).toLocaleString();
                const ticketLink = alert.ticketId ? 
                    '<a href="#" style="color: #667eea; text-decoration: none;">' + alert.ticketId + '</a>' : 
                    'N/A';
                
                tableHtml += 
                    '<tr>' +
                        '<td>' + timestamp + '</td>' +
                        '<td><span class="status-badge ' + statusClass + '">' + alert.status + '</span></td>' +
                        '<td>' + (alert.client || 'N/A') + '</td>' +
                        '<td>' + (alert.device || 'N/A') + '</td>' +
                        '<td>' + (alert.alertType || 'N/A') + '</td>' +
                        '<td title="' + (alert.error || alert.summary) + '">' + truncateText(alert.summary || alert.error || 'N/A', 50) + '</td>' +
                        '<td>' + ticketLink + '</td>' +
                        '<td>' + alert.processingTimeSeconds + 's</td>' +
                    '</tr>';
            });
            
            tableHtml += '</tbody></table>';
            document.getElementById('alertsContent').innerHTML = tableHtml;
        }
        
        function updateClientFilter(alerts) {
            const clients = [...new Set(alerts.map(alert => alert.client).filter(client => client))];
            const clientFilter = document.getElementById('clientFilter');
            const currentValue = clientFilter.value;
            
            clientFilter.innerHTML = '<option value="all">All Clients</option>';
            clients.forEach(client => {
                const option = document.createElement('option');
                option.value = client;
                option.textContent = client;
                clientFilter.appendChild(option);
            });
            
            // Restore previous selection if it still exists
            if (clients.includes(currentValue)) {
                clientFilter.value = currentValue;
            }
        }
        
        function updateLastUpdated() {
            const now = new Date().toLocaleString();
            document.getElementById('lastUpdated').textContent = 'Last updated: ' + now;
        }
        
        function truncateText(text, maxLength) {
            if (!text) return 'N/A';
            if (text.length <= maxLength) return text;
            return text.substring(0, maxLength) + '...';
        }
        
        // Add event listeners for filters
        ['days', 'statusFilter', 'alertTypeFilter', 'clientFilter'].forEach(id => {
            document.getElementById(id).addEventListener('change', refreshData);
        });
    </script>
</body>
</html>
"@
}

function Get-AlertDataForDashboard {
    param($Request)
    
    try {
        # Parse filter parameters
        $days = [int]($Request.Query.days ?? 5)
        $statusFilter = $Request.Query.status ?? "all"
        $alertTypeFilter = $Request.Query.alertType ?? "all"
        $clientFilter = $Request.Query.client ?? "all"
        
        $dateFrom = (Get-Date).AddDays(-$days)
        $dateTo = Get-Date
        
        $filters = @{
            status = $statusFilter
            alertType = $alertTypeFilter
            client = $clientFilter
        }
        
        # Try to get logs from Application Insights
        try {
            # Import the Application Insights helper module
            Import-Module "$PSScriptRoot\..\Modules\ApplicationInsightsHelper.psm1" -Force
            
            Write-Host "Getting dashboard data with filters: $($filters | ConvertTo-Json -Compress)"
            $dashboardData = Get-AlertDashboardData -DateFrom $dateFrom -DateTo $dateTo -Filters $filters
            return $dashboardData
        }
        catch {
            Write-Host "Failed to get Application Insights data: $($_.Exception.Message)"
            # Fallback to sample data for demonstration
            return Get-SampleAlertData -DateFrom $dateFrom -DateTo $dateTo -Filters $filters
        }
    }
    catch {
        Write-Host "Error in Get-AlertDataForDashboard: $($_.Exception.Message)"
        return @{
            alerts = @()
            stats = @{
                totalAlerts = 0
                successCount = 0
                errorCount = 0
                resolvedCount = 0
                avgProcessingTime = 0
            }
            dateRange = @{
                from = (Get-Date).AddDays(-5).ToString('yyyy-MM-dd HH:mm:ss')
                to = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
    }
}

function Get-SampleAlertData {
    param(
        [datetime]$DateFrom,
        [datetime]$DateTo,
        [hashtable]$Filters = @{}
    )
    
    # Generate sample alerts for demonstration
    $sampleAlerts = @()
    $random = New-Object System.Random
    
    $clients = @("Acme Corp", "TechStart LLC", "Global Solutions", "Innovation Inc", "Future Systems")
    $alertTypes = @("Memory High", "CPU High", "Host File Changes", "Service Down")
    
    # Generate 50 sample alerts
    for ($i = 0; $i -lt 50; $i++) {
        $alertTime = $DateFrom.AddMinutes($random.Next(0, [int]($DateTo - $DateFrom).TotalMinutes))
        $client = $clients[$random.Next(0, $clients.Length)]
        $alertType = $alertTypes[$random.Next(0, $alertTypes.Length)]
        $device = "WKS-" + $random.Next(1000, 9999).ToString()
        $alertUID = [System.Guid]::NewGuid().ToString()
        
        # 75% success rate
        $status = if ($random.NextDouble() -lt 0.75) { "success" } else { "error" }
        
        $summary = switch ($alertType) {
            "Memory High" { "Device: $device raised Alert: Memory usage at $($random.Next(85, 99))%" }
            "Host File Changes" { "Device: $device raised Alert: Hosts file modification detected" }
            "Service Down" { "Device: $device raised Alert: Critical service stopped" }
            "CPU High" { "Device: $device raised Alert: CPU usage at $($random.Next(80, 100))%" }
            default { "Device: $device raised Alert: $alertType" }
        }
        
        $errorMessage = $null
        $ticketId = $null
        $processingTime = $random.Next(1, 10)
        
        if ($status -eq "success") {
            $ticketId = $random.Next(180000, 190000)
        } elseif ($status -eq "error") {
            $errors = @(
                "Failed to connect to Halo API",
                "Invalid client configuration",
                "Ticket creation failed",
                "Alert consolidation error",
                "Missing device information"
            )
            $errorMessage = $errors[$random.Next(0, $errors.Length)]
        }
        
        $alert = @{
            timestamp = $alertTime.ToString('yyyy-MM-ddTHH:mm:ss')
            alertUID = $alertUID
            status = $status
            client = $client
            device = $device
            alertType = $alertType
            summary = $summary
            error = $errorMessage
            ticketId = $ticketId
            processingTimeSeconds = $processingTime
            resolved = ($status -eq "success" -and $random.Next(1, 101) -le 30) # 30% chance of being resolved
        }
        
        $sampleAlerts += $alert
    }
    
    # Apply filters
    $filteredAlerts = $sampleAlerts
    
    if ($Filters.status -and $Filters.status -ne "all") {
        $filteredAlerts = $filteredAlerts | Where-Object { $_.status -eq $Filters.status }
    }
    
    if ($Filters.alertType -and $Filters.alertType -ne "all") {
        $filteredAlerts = $filteredAlerts | Where-Object { $_.alertType -eq $Filters.alertType }
    }
    
    if ($Filters.client -and $Filters.client -ne "all") {
        $filteredAlerts = $filteredAlerts | Where-Object { $_.client -eq $Filters.client }
    }
    
    # Sort by timestamp (newest first)
    $filteredAlerts = $filteredAlerts | Sort-Object timestamp -Descending
    
    # Calculate statistics
    $stats = @{
        totalAlerts = $filteredAlerts.Count
        successCount = ($filteredAlerts | Where-Object { $_.status -eq "success" }).Count
        errorCount = ($filteredAlerts | Where-Object { $_.status -eq "error" }).Count
        resolvedCount = ($filteredAlerts | Where-Object { $_.resolved -eq $true }).Count
        avgProcessingTime = if ($filteredAlerts.Count -gt 0) { 
            [math]::Round(($filteredAlerts | Measure-Object -Property processingTimeSeconds -Average).Average, 2) 
        } else { 0 }
    }
    
    return @{
        alerts = $filteredAlerts
        stats = $stats
        dateRange = @{
            from = $DateFrom.ToString('yyyy-MM-dd HH:mm:ss')
            to = $DateTo.ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
}

# Main execution logic
try {
    # Extract action from route parameter or query string
    $action = if ($Request.Params.action) { 
        $Request.Params.action 
    } elseif ($Request.Query.action) { 
        $Request.Query.action 
    } else { 
        'view' 
    }
    
    Write-Host "Alert Dashboard - Action: $action"
    Write-Host "Request URL: $($Request.Url)"
    Write-Host "Request Method: $($Request.Method)"
    Write-Host "Request Params: $($Request.Params | ConvertTo-Json -Compress)"
    Write-Host "Request Query: $($Request.Query | ConvertTo-Json -Compress)"
    
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
Push-OutputBinding -Name Response -Value @{
    StatusCode = $response.StatusCode
    ContentType = if ($response.Headers -and $response.Headers['Content-Type']) { $response.Headers['Content-Type'] } else { 'text/html' }
    Body = $response.Body
}