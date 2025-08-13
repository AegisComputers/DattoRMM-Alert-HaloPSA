using namespace System.Net
using namespace Microsoft.Azure.Cosmos.Table

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Set up error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    # Get the action from the route (default to 'view')
    $action = if ($Request.Params.action) { $Request.Params.action } else { 'view' }
    
    Write-Host "Alert Dashboard - Action: $action"
    
    switch ($action.ToLower()) {
        'view' {
            # Serve the main dashboard HTML
            $htmlContent = Get-DashboardHtml
            $response = @{
                StatusCode = [HttpStatusCode]::OK
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                Body = $htmlContent
            }
        }
        'api' {
            # Handle API requests for alert data
            $alertData = Get-AlertDataForDashboard -Request $Request
            $response = @{
                StatusCode = [HttpStatusCode]::OK
                Headers = @{ 'Content-Type' = 'application/json' }
                Body = ($alertData | ConvertTo-Json -Depth 10)
            }
        }
        default {
            # Default to dashboard view
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
    Write-Host "ERROR in Alert Dashboard: $($_.Exception.Message)" -ForegroundColor Red
    $response = @{
        StatusCode = [HttpStatusCode]::InternalServerError
        Headers = @{ 'Content-Type' = 'application/json' }
        Body = @{
            error = "Failed to load dashboard"
            message = $_.Exception.Message
        } | ConvertTo-Json
    }
}

# Return the response
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $response.StatusCode
    Headers = $response.Headers
    Body = $response.Body
})

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
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 300;
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .filters {
            background: #f8f9fa;
            padding: 25px;
            border-bottom: 1px solid #dee2e6;
        }
        
        .filter-row {
            display: flex;
            gap: 20px;
            align-items: center;
            flex-wrap: wrap;
            margin-bottom: 15px;
        }
        
        .filter-group {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }
        
        .filter-group label {
            font-weight: 600;
            color: #495057;
            font-size: 0.9em;
        }
        
        .filter-group select, .filter-group input {
            padding: 8px 12px;
            border: 2px solid #dee2e6;
            border-radius: 6px;
            font-size: 0.9em;
            transition: border-color 0.3s ease;
        }
        
        .filter-group select:focus, .filter-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s ease;
            text-transform: uppercase;
            font-size: 0.85em;
            letter-spacing: 0.5px;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 15px rgba(102, 126, 234, 0.4);
        }
        
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        
        .btn-secondary:hover {
            background: #5a6268;
            transform: translateY(-1px);
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 25px;
            background: #f8f9fa;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #6c757d;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.8em;
            letter-spacing: 0.5px;
        }
        
        .stat-success { color: #28a745; }
        .stat-error { color: #dc3545; }
        .stat-warning { color: #ffc107; }
        .stat-info { color: #17a2b8; }
        
        .content {
            padding: 25px;
        }
        
        .loading {
            text-align: center;
            padding: 50px;
            color: #6c757d;
        }
        
        .loading::after {
            content: '';
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-left: 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .alert-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .alert-table th {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.8em;
            letter-spacing: 0.5px;
        }
        
        .alert-table td {
            padding: 15px;
            border-bottom: 1px solid #dee2e6;
            vertical-align: top;
        }
        
        .alert-table tr:hover {
            background: #f8f9fa;
        }
        
        .status-badge {
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .status-success {
            background: #d4edda;
            color: #155724;
        }
        
        .status-error {
            background: #f8d7da;
            color: #721c24;
        }
        
        .status-warning {
            background: #fff3cd;
            color: #856404;
        }
        
        .status-info {
            background: #d1ecf1;
            color: #0c5460;
        }
        
        .alert-details {
            font-size: 0.9em;
            color: #6c757d;
            margin-top: 5px;
        }
        
        .no-alerts {
            text-align: center;
            padding: 50px;
            color: #6c757d;
            font-size: 1.1em;
        }
        
        .refresh-info {
            text-align: center;
            padding: 15px;
            background: #e9ecef;
            color: #6c757d;
            font-size: 0.9em;
        }
        
        @media (max-width: 768px) {
            .filter-row {
                flex-direction: column;
                align-items: stretch;
            }
            
            .stats {
                grid-template-columns: repeat(2, 1fr);
            }
            
            .alert-table {
                font-size: 0.8em;
            }
            
            .alert-table th, .alert-table td {
                padding: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 Datto RMM Alert Dashboard</h1>
            <p>Monitor and analyze your alert processing status</p>
        </div>
        
        <div class="filters">
            <div class="filter-row">
                <div class="filter-group">
                    <label for="statusFilter">Status Filter</label>
                    <select id="statusFilter">
                        <option value="">All Statuses</option>
                        <option value="success">Success</option>
                        <option value="error">Error</option>
                        <option value="warning">Warning</option>
                        <option value="processing">Processing</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label for="clientFilter">Client Filter</label>
                    <select id="clientFilter">
                        <option value="">All Clients</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label for="alertTypeFilter">Alert Type</label>
                    <select id="alertTypeFilter">
                        <option value="">All Types</option>
                    </select>
                </div>
                
                <div class="filter-group">
                    <label for="dateFrom">Date From</label>
                    <input type="date" id="dateFrom">
                </div>
                
                <div class="filter-group">
                    <label for="dateTo">Date To</label>
                    <input type="date" id="dateTo">
                </div>
            </div>
            
            <div class="filter-row">
                <button class="btn btn-primary" onclick="loadAlerts()">🔍 Apply Filters</button>
                <button class="btn btn-secondary" onclick="resetFilters()">🔄 Reset</button>
                <button class="btn btn-secondary" onclick="autoRefreshToggle()">⏰ Auto Refresh: OFF</button>
            </div>
        </div>
        
        <div class="stats" id="statsContainer">
            <div class="stat-card">
                <div class="stat-number stat-info" id="totalAlerts">-</div>
                <div class="stat-label">Total Alerts</div>
            </div>
            <div class="stat-card">
                <div class="stat-number stat-success" id="successAlerts">-</div>
                <div class="stat-label">Successful</div>
            </div>
            <div class="stat-card">
                <div class="stat-number stat-error" id="errorAlerts">-</div>
                <div class="stat-label">Errors</div>
            </div>
            <div class="stat-card">
                <div class="stat-number stat-warning" id="warningAlerts">-</div>
                <div class="stat-label">Warnings</div>
            </div>
        </div>
        
        <div class="content">
            <div id="alertsContainer">
                <div class="loading">Loading alerts...</div>
            </div>
        </div>
        
        <div class="refresh-info">
            Last updated: <span id="lastUpdated">Never</span> | 
            <a href="#" onclick="loadAlerts()">Refresh Now</a>
        </div>
    </div>

    <script>
        let autoRefreshInterval = null;
        let autoRefreshEnabled = false;
        
        // Initialize dashboard
        document.addEventListener('DOMContentLoaded', function() {
            initializeDateFilters();
            loadAlerts();
        });
        
        function initializeDateFilters() {
            const dateTo = document.getElementById('dateTo');
            const dateFrom = document.getElementById('dateFrom');
            
            // Set default dates (last 5 days)
            const today = new Date();
            const fiveDaysAgo = new Date(today.getTime() - (5 * 24 * 60 * 60 * 1000));
            
            dateTo.value = today.toISOString().split('T')[0];
            dateFrom.value = fiveDaysAgo.toISOString().split('T')[0];
        }
        
        async function loadAlerts() {
            const container = document.getElementById('alertsContainer');
            container.innerHTML = '<div class="loading">Loading alerts...</div>';
            
            try {
                const filters = getFilters();
                const response = await fetch(window.location.origin + '/api/dashboard/api', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(filters)
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${"$"}{response.status}`);
                }
                
                const data = await response.json();
                displayAlerts(data);
                updateStats(data);
                updateFilters(data);
                updateLastUpdated();
                
            } catch (error) {
                console.error('Error loading alerts:', error);
                container.innerHTML = `
                    <div class="no-alerts">
                        ❌ Error loading alerts: ${"$"}{error.message}<br>
                        <button class="btn btn-primary" onclick="loadAlerts()" style="margin-top: 15px;">Try Again</button>
                    </div>
                `;
            }
        }
        
        function getFilters() {
            return {
                status: document.getElementById('statusFilter').value,
                client: document.getElementById('clientFilter').value,
                alertType: document.getElementById('alertTypeFilter').value,
                dateFrom: document.getElementById('dateFrom').value,
                dateTo: document.getElementById('dateTo').value
            };
        }
        
        function displayAlerts(data) {
            const container = document.getElementById('alertsContainer');
            
            if (!data.alerts || data.alerts.length === 0) {
                container.innerHTML = '<div class="no-alerts">📭 No alerts found for the selected criteria</div>';
                return;
            }
            
            let html = `
                <table class="alert-table">
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Alert UID</th>
                            <th>Status</th>
                            <th>Client</th>
                            <th>Device</th>
                            <th>Alert Type</th>
                            <th>Details</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            data.alerts.forEach(alert => {
                const statusClass = getStatusClass(alert.status);
                const timestamp = new Date(alert.timestamp).toLocaleString();
                
                html += `
                    <tr>
                        <td>${"$"}{timestamp}</td>
                        <td><code>${"$"}{alert.alertUID || 'N/A'}</code></td>
                        <td><span class="status-badge ${"$"}{statusClass}">${"$"}{alert.status}</span></td>
                        <td>${"$"}{alert.client || 'Unknown'}</td>
                        <td>${"$"}{alert.device || 'Unknown'}</td>
                        <td>${"$"}{alert.alertType || 'Unknown'}</td>
                        <td>
                            ${"$"}{alert.summary || 'No summary'}
                            ${"$"}{alert.error ? `<div class="alert-details">❌ ${"$"}{alert.error}</div>` : ''}
                            ${"$"}{alert.ticketId ? `<div class="alert-details">🎫 Ticket: ${"$"}{alert.ticketId}</div>` : ''}
                        </td>
                    </tr>
                `;
            });
            
            html += '</tbody></table>';
            container.innerHTML = html;
        }
        
        function getStatusClass(status) {
            switch (status?.toLowerCase()) {
                case 'success': return 'status-success';
                case 'error': return 'status-error';
                case 'warning': return 'status-warning';
                default: return 'status-info';
            }
        }
        
        function updateStats(data) {
            document.getElementById('totalAlerts').textContent = data.stats.total || 0;
            document.getElementById('successAlerts').textContent = data.stats.success || 0;
            document.getElementById('errorAlerts').textContent = data.stats.error || 0;
            document.getElementById('warningAlerts').textContent = data.stats.warning || 0;
        }
        
        function updateFilters(data) {
            // Update client filter
            const clientFilter = document.getElementById('clientFilter');
            const currentClient = clientFilter.value;
            clientFilter.innerHTML = '<option value="">All Clients</option>';
            
            if (data.filters && data.filters.clients) {
                data.filters.clients.forEach(client => {
                    const option = document.createElement('option');
                    option.value = client;
                    option.textContent = client;
                    if (client === currentClient) option.selected = true;
                    clientFilter.appendChild(option);
                });
            }
            
            // Update alert type filter
            const alertTypeFilter = document.getElementById('alertTypeFilter');
            const currentAlertType = alertTypeFilter.value;
            alertTypeFilter.innerHTML = '<option value="">All Types</option>';
            
            if (data.filters && data.filters.alertTypes) {
                data.filters.alertTypes.forEach(type => {
                    const option = document.createElement('option');
                    option.value = type;
                    option.textContent = type;
                    if (type === currentAlertType) option.selected = true;
                    alertTypeFilter.appendChild(option);
                });
            }
        }
        
        function updateLastUpdated() {
            document.getElementById('lastUpdated').textContent = new Date().toLocaleString();
        }
        
        function resetFilters() {
            document.getElementById('statusFilter').value = '';
            document.getElementById('clientFilter').value = '';
            document.getElementById('alertTypeFilter').value = '';
            initializeDateFilters();
            loadAlerts();
        }
        
        function autoRefreshToggle() {
            const button = event.target;
            
            if (autoRefreshEnabled) {
                clearInterval(autoRefreshInterval);
                autoRefreshEnabled = false;
                button.textContent = '⏰ Auto Refresh: OFF';
                button.classList.remove('btn-primary');
                button.classList.add('btn-secondary');
            } else {
                autoRefreshInterval = setInterval(loadAlerts, 30000); // Refresh every 30 seconds
                autoRefreshEnabled = true;
                button.textContent = '⏰ Auto Refresh: ON (30s)';
                button.classList.remove('btn-secondary');
                button.classList.add('btn-primary');
            }
        }
    </script>
</body>
</html>
"@
}

function Get-AlertDataForDashboard {
    param($Request)
    
    try {
        # Parse filters from request body
        $filters = @{}
        if ($Request.Body) {
            $bodyJson = $Request.Body | ConvertFrom-Json
            $filters = $bodyJson
        }
        
        # Set default date range (last 5 days)
        $dateTo = if ($filters.dateTo) { [DateTime]::Parse($filters.dateTo) } else { Get-Date }
        $dateFrom = if ($filters.dateFrom) { [DateTime]::Parse($filters.dateFrom) } else { $dateTo.AddDays(-5) }
        
        Write-Host "Loading alerts from $dateFrom to $dateTo"
        
        # Connect to Halo API
        $HaloClientID = $env:HaloClientID
        $HaloClientSecret = $env:HaloClientSecret
        $HaloURL = $env:HaloURL
        
        if ($HaloClientID -and $HaloClientSecret -and $HaloURL) {
            Connect-HaloAPI -URL $HaloURL -ClientId $HaloClientID -ClientSecret $HaloClientSecret -Scopes "all"
            
            # Get alerts report
            $alertsReport = Get-HaloReport -Search "Datto RMM Improved Alerts PowerShell Function - Alerts Report"
            if ($alertsReport) {
                $reportToUse = if ($alertsReport -is [array]) { $alertsReport[0] } else { $alertsReport }
                $alertsData = Invoke-HaloReport -Report $reportToUse -IncludeReport
                
                # Process and filter alerts
                $processedAlerts = @()
                $stats = @{
                    total = 0
                    success = 0
                    error = 0
                    warning = 0
                }
                
                $clients = @()
                $alertTypes = @()
                
                foreach ($alert in $alertsData) {
                    # Parse date
                    $alertDate = $null
                    if ($alert.dateoccured) {
                        try {
                            $alertDate = [DateTime]::Parse($alert.dateoccured)
                        } catch {
                            Write-Host "Failed to parse date: $($alert.dateoccured)"
                            continue
                        }
                    } else {
                        continue
                    }
                    
                    # Filter by date range
                    if ($alertDate -lt $dateFrom -or $alertDate -gt $dateTo) {
                        continue
                    }
                    
                    # Determine status based on ticket status
                    $status = switch ($alert.tstatusdesc) {
                        "Closed" { "success" }
                        "New" { "warning" }
                        "In Progress" { "warning" }
                        "On Hold" { "warning" }
                        default { "info" }
                    }
                    
                    # Extract client and device info
                    $client = "Unknown"
                    $device = "Unknown"
                    
                    # Try to extract from symptom/summary
                    if ($alert.Symptom -match "Device:\s*([^\s]+)") {
                        $device = $matches[1]
                    }
                    
                    # Build processed alert object
                    $processedAlert = @{
                        timestamp = $alertDate.ToString('yyyy-MM-ddTHH:mm:ss')
                        alertUID = $alert.CFDattoAlertUID
                        status = $status
                        client = $client
                        device = $device
                        alertType = $alert.CFDattoAlertType
                        summary = $alert.Symptom
                        ticketId = $alert.Faultid
                        ticketStatus = $alert.tstatusdesc
                    }
                    
                    # Apply filters
                    $includeAlert = $true
                    
                    if ($filters.status -and $status -ne $filters.status) {
                        $includeAlert = $false
                    }
                    
                    if ($filters.client -and $client -notlike "*$($filters.client)*") {
                        $includeAlert = $false
                    }
                    
                    if ($filters.alertType -and $alert.CFDattoAlertType -notlike "*$($filters.alertType)*") {
                        $includeAlert = $false
                    }
                    
                    if ($includeAlert) {
                        $processedAlerts += $processedAlert
                        $stats.total++
                        
                        switch ($status) {
                            "success" { $stats.success++ }
                            "error" { $stats.error++ }
                            "warning" { $stats.warning++ }
                        }
                        
                        # Collect unique values for filters
                        if ($client -and $clients -notcontains $client) {
                            $clients += $client
                        }
                        
                        if ($alert.CFDattoAlertType -and $alertTypes -notcontains $alert.CFDattoAlertType) {
                            $alertTypes += $alert.CFDattoAlertType
                        }
                    }
                }
                
                # Sort alerts by timestamp (newest first)
                $processedAlerts = $processedAlerts | Sort-Object timestamp -Descending
                
                return @{
                    alerts = $processedAlerts
                    stats = $stats
                    filters = @{
                        clients = ($clients | Sort-Object)
                        alertTypes = ($alertTypes | Sort-Object)
                    }
                    dateRange = @{
                        from = $dateFrom.ToString('yyyy-MM-dd')
                        to = $dateTo.ToString('yyyy-MM-dd')
                    }
                }
            }
        }
        
        # Fallback - return empty data structure
        return @{
            alerts = @()
            stats = @{
                total = 0
                success = 0
                error = 0
                warning = 0
            }
            filters = @{
                clients = @()
                alertTypes = @()
            }
            error = "Unable to connect to Halo API or retrieve data"
        }
    }
    catch {
        Write-Host "Error in Get-AlertDataForDashboard: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            alerts = @()
            stats = @{
                total = 0
                success = 0
                error = 0
                warning = 0
            }
            filters = @{
                clients = @()
                alertTypes = @()
            }
            error = $_.Exception.Message
        }
    }
}
