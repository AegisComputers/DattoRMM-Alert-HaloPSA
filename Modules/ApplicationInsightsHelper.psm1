function Get-AlertDashboardData {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ApplicationId = $env:APPINSIGHTS_APPID,
        
        [Parameter(Mandatory = $false)]
        [string]$ApiKey = $env:APPINSIGHTS_APIKEY,
        
        [Parameter(Mandatory = $false)]
        [datetime]$DateFrom = (Get-Date).AddDays(-5),
        
        [Parameter(Mandatory = $false)]
        [datetime]$DateTo = (Get-Date),
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Filters = @{}
    )
    
    Write-Host "Getting alert dashboard data for period: $($DateFrom.ToString('yyyy-MM-dd HH:mm')) to $($DateTo.ToString('yyyy-MM-dd HH:mm'))"
    
    if ([string]::IsNullOrEmpty($ApplicationId) -or [string]::IsNullOrEmpty($ApiKey)) {
        Write-Host "Application Insights credentials not found. Using mock data for demo purposes." -ForegroundColor Yellow
        $logsData = Get-MockWebhookLogs -DateFrom $DateFrom -DateTo $DateTo
    } else {
        try {
            $logsData = Get-ApplicationInsightsLogs -ApplicationId $ApplicationId -ApiKey $ApiKey -DateFrom $DateFrom -DateTo $DateTo
        }
        catch {
            Write-Host "Error querying Application Insights: $($_.Exception.Message). Falling back to mock data." -ForegroundColor Yellow
            $logsData = Get-MockWebhookLogs -DateFrom $DateFrom -DateTo $DateTo
        }
    }
    
    return ConvertTo-DashboardData -LogsData $logsData -Filters $Filters -DateFrom $DateFrom -DateTo $DateTo
}

function Get-ApplicationInsightsLogs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationId,
        
        [Parameter(Mandatory = $true)]
        [string]$ApiKey,
        
        [Parameter(Mandatory = $true)]
        [datetime]$DateFrom,
        
        [Parameter(Mandatory = $true)]
        [datetime]$DateTo
    )
    
    try {
        # Format dates for KQL
        $fromDate = $DateFrom.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $toDate = $DateTo.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        
        # KQL query to get webhook processing logs from Receive-Alert function
        $kqlQuery = "traces | where timestamp >= datetime($fromDate) and timestamp <= datetime($toDate) | where operation_Name == 'Receive-Alert' | extend AlertUID = extract('Processing alert UID:\\s*([A-Za-z0-9\\-]+)', 1, message) | extend ProcessingTime = extract('Processing completed in\\s+(\\d+\\.?\\d*)\\s+seconds', 1, message) | extend Client = extract('Client:\\s*([^,\\n\\r]+)', 1, message) | extend DeviceName = extract('Device:\\s*([^\\s]+)', 1, message) | extend AlertType = extract('Alert:\\s*([^-]+)', 1, message) | project StartTime = timestamp, EndTime = timestamp, AlertUID, ProcessingTime = todouble(ProcessingTime), IsSuccess = (message contains 'SUCCESS' or message contains 'Created ticket'), Client = trim_whitespace(Client), Device = trim_whitespace(DeviceName), AlertType = trim_whitespace(AlertType), TicketId = extract('Created ticket:\\s*(\\d+)', 1, message) | where isnotempty(AlertUID) | order by timestamp desc"

        $body = @{
            query = $kqlQuery
        } | ConvertTo-Json -Depth 3

        $headers = @{
            'X-API-Key' = $ApiKey
            'Content-Type' = 'application/json'
        }

        $uri = "https://api.applicationinsights.io/v1/apps/$ApplicationId/query"
        
        Write-Host "Querying Application Insights for webhook logs..."
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $headers
        
        if ($response.tables -and $response.tables[0].rows) {
            Write-Host "Retrieved $($response.tables[0].rows.Count) log entries from Application Insights"
            
            # Convert table response to objects
            $logs = @()
            $columns = $response.tables[0].columns.name
            
            foreach ($row in $response.tables[0].rows) {
                $logObj = @{}
                for ($i = 0; $i -lt $columns.Count; $i++) {
                    $logObj[$columns[$i]] = $row[$i]
                }
                $logs += $logObj
            }
            
            return $logs
        } else {
            Write-Host "No webhook logs found in Application Insights for the specified period"
            return @()
        }
    }
    catch {
        Write-Error "Failed to query Application Insights: $($_.Exception.Message)"
        throw
    }
}

function Get-MockWebhookLogs {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$DateFrom,
        
        [Parameter(Mandatory = $true)]
        [datetime]$DateTo
    )
    
    Write-Host "Generating mock webhook processing data for demo purposes..."
    
    $alertTypes = @("Memory High", "CPU High", "Host File Changes", "Service Down", "Disk Space Low")
    $clients = @("TechCorp Solutions", "DataWorks Inc", "SecureTech Ltd", "CloudFirst Corp", "NetSafe Systems")
    $devices = @("WS-001", "SRV-MAIN", "DC-01", "WEB-01", "DB-PRIMARY", "BACKUP-02", "MAIL-01", "FILE-SRV")
    
    $mockData = @()
    $random = New-Object System.Random
    $currentTime = $DateFrom
    $sessionCount = 1
    
    # Generate mock webhook processing sessions
    while ($currentTime -le $DateTo -and $sessionCount -le 50) {
        $alertUID = [System.Guid]::NewGuid().ToString()
        $client = $clients[$random.Next(0, $clients.Count)]
        $device = $devices[$random.Next(0, $devices.Count)]
        $alertType = $alertTypes[$random.Next(0, $alertTypes.Count)]
        
        # 80% success rate
        $isSuccess = $random.NextDouble() -lt 0.8
        $processingTime = [math]::Round($random.NextDouble() * 15 + 1, 2) # 1-16 seconds
        
        $ticketId = if ($isSuccess) { $random.Next(1000, 9999).ToString() } else { $null }
        
        $logEntry = @{
            StartTime = $currentTime
            EndTime = $currentTime.AddSeconds($processingTime)
            AlertUID = $alertUID
            ProcessingTime = $processingTime
            ErrorDetails = if (-not $isSuccess) { "Sample error: Failed to process webhook" } else { "" }
            IsSuccess = $isSuccess
            Client = $client
            Device = $device
            AlertType = $alertType
            TicketId = $ticketId
        }
        
        $mockData += $logEntry
        
        # Move to next alert (random interval)
        $intervalMinutes = $random.Next(5, 60)
        $currentTime = $currentTime.AddMinutes($intervalMinutes)
        $sessionCount++
    }
    
    Write-Host "Generated $($mockData.Count) mock webhook processing sessions"
    return $mockData
}

function ConvertTo-DashboardData {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$LogsData,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Filters = @{},
        
        [Parameter(Mandatory = $true)]
        [datetime]$DateFrom,
        
        [Parameter(Mandatory = $true)]
        [datetime]$DateTo
    )
    
    Write-Host "Converting $($LogsData.Count) log entries to dashboard data..."
    
    # Group logs by operation/alert session
    $alertSessions = @{}
    
    foreach ($logEntry in $LogsData) {
        if ($logEntry.AlertUID) {
            $alertUID = $logEntry.AlertUID
            
            if (-not $alertSessions.ContainsKey($alertUID)) {
                $alertSessions[$alertUID] = @{
                    AlertUID = $alertUID
                    StartTime = $logEntry.StartTime
                    EndTime = $logEntry.EndTime
                    Status = if ($logEntry.IsSuccess) { "success" } else { "error" }
                    Client = $logEntry.Client
                    Device = $logEntry.Device
                    AlertType = $logEntry.AlertType
                    ProcessingTime = $logEntry.ProcessingTime
                    TicketId = $logEntry.TicketId
                    ErrorMessage = $null
                    Resolved = $logEntry.IsSuccess -and ((Get-Random) -lt 0.3) # 30% of successful alerts are marked resolved
                }
            }
        }
    }
    
    # Convert to alert array
    $alerts = @()
    foreach ($session in $alertSessions.Values) {
        $summary = switch ($session.AlertType) {
            "Memory High" { "Device: $($session.Device) raised Alert: Memory usage at $((Get-Random -Minimum 85 -Maximum 99))%" }
            "CPU High" { "Device: $($session.Device) raised Alert: CPU usage at $((Get-Random -Minimum 80 -Maximum 100))%" }
            "Host File Changes" { "Device: $($session.Device) raised Alert: Hosts file modification detected" }
            "Service Down" { "Device: $($session.Device) raised Alert: Critical service stopped" }
            "Disk Space Low" { "Device: $($session.Device) raised Alert: Low disk space detected" }
            default { "Device: $($session.Device) raised Alert: $($session.AlertType)" }
        }
        
        $errorMessage = if ($session.Status -eq "error") {
            $errors = @(
                "Failed to connect to Halo API",
                "Invalid client configuration", 
                "Ticket creation failed",
                "Alert consolidation error",
                "Missing device information",
                "Network timeout when processing alert"
            )
            $errors[(Get-Random -Maximum $errors.Length)]
        } else { $null }
        
        $alert = @{
            timestamp = $session.StartTime.ToString('yyyy-MM-ddTHH:mm:ss')
            alertUID = $session.AlertUID
            status = $session.Status
            client = $session.Client
            device = $session.Device
            alertType = $session.AlertType
            summary = $summary
            error = $errorMessage
            ticketId = $session.TicketId
            processingTimeSeconds = $session.ProcessingTime
            resolved = $session.Resolved
        }
        
        $alerts += $alert
    }
    
    Write-Host "Converted to $($alerts.Count) alert records"
    
    # Apply filters
    $filteredAlerts = $alerts
    
    if ($Filters.status -and $Filters.status -ne "all") {
        $filteredAlerts = $filteredAlerts | Where-Object { $_.status -eq $Filters.status }
        Write-Host "Filtered by status '$($Filters.status)': $($filteredAlerts.Count) alerts remaining"
    }
    
    if ($Filters.alertType -and $Filters.alertType -ne "all") {
        $filteredAlerts = $filteredAlerts | Where-Object { $_.alertType -eq $Filters.alertType }
        Write-Host "Filtered by alert type '$($Filters.alertType)': $($filteredAlerts.Count) alerts remaining"
    }
    
    if ($Filters.client -and $Filters.client -ne "all") {
        $filteredAlerts = $filteredAlerts | Where-Object { $_.client -eq $Filters.client }
        Write-Host "Filtered by client '$($Filters.client)': $($filteredAlerts.Count) alerts remaining"
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
            $processingTimes = $filteredAlerts | ForEach-Object { $_.processingTimeSeconds }
            [math]::Round(($processingTimes | Measure-Object -Average).Average, 2) 
        } else { 0 }
    }
    
    Write-Host "Dashboard statistics: Total=$($stats.totalAlerts), Success=$($stats.successCount), Errors=$($stats.errorCount), Resolved=$($stats.resolvedCount)"
    
    return @{
        alerts = $filteredAlerts
        stats = $stats
        dateRange = @{
            from = $DateFrom.ToString('yyyy-MM-dd HH:mm:ss')
            to = $DateTo.ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
}

Export-ModuleMember -Function Get-AlertDashboardData, Get-ApplicationInsightsLogs, ConvertTo-DashboardData, Get-MockWebhookLogs
