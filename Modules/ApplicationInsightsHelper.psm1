# Azure Application Insights Log Query Module
# This module provides functions to query Application Insights for webhook processing logs

function Get-ApplicationInsightsData {
    param(
        [Parameter(Mandatory)]
        [DateTime]$StartTime,
        [Parameter(Mandatory)]
        [DateTime]$EndTime,
        [string]$ApplicationId,
        [string]$ApiKey
    )
    
    if (-not $ApplicationId) {
        $ApplicationId = $env:APPINSIGHTS_APPLICATION_ID
    }
    
    if (-not $ApiKey) {
        $ApiKey = $env:APPINSIGHTS_API_KEY
    }
    
    if (-not $ApplicationId -or -not $ApiKey) {
        throw "Application Insights Application ID and API Key are required"
    }
    
    # KQL Query to get webhook processing data
    $kqlQuery = @"
union traces, exceptions, requests
| where timestamp >= datetime('$($StartTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))')
| where timestamp <= datetime('$($EndTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))')
| where operation_Name == "Receive-Alert" or cloud_RoleName == "Receive-Alert"
| extend AlertUID = extract(@"Alert with the UID of - ([^-\s]+)", 1, message)
| extend Client = extract(@"Client ID in Halo - ([^-\s]+)", 1, message)
| extend ProcessingTime = extract(@"Total processing time: ([^s]+)", 1, message)
| extend TicketID = extract(@"Created new.*ticket.*ID.*?(\d+)", 1, message)
| extend ErrorMessage = iff(itemType == "exception", outerMessage, "")
| extend Status = case(
    itemType == "exception", "error",
    message contains "successfully", "success",
    message contains "consolidat", "success",
    message contains "ERROR", "error",
    message contains "WARNING", "warning",
    "info"
)
| extend DeviceName = extract(@"Device:\s*([^\s]+)", 1, message)
| extend AlertType = extract(@"Alert:\s*([^-]+)", 1, message)
| project 
    timestamp,
    AlertUID,
    Status,
    Client,
    DeviceName,
    AlertType,
    TicketID,
    ProcessingTime,
    ErrorMessage,
    message,
    operation_Id
| where isnotempty(AlertUID) or Status == "error"
| order by timestamp desc
"@

    $body = @{
        query = $kqlQuery
    } | ConvertTo-Json -Depth 3

    $headers = @{
        'X-API-Key' = $ApiKey
        'Content-Type' = 'application/json'
    }

    $uri = "https://api.applicationinsights.io/v1/apps/$ApplicationId/query"
    
    try {
        Write-Host "Querying Application Insights with KQL query..."
        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers
        
        if ($response.tables -and $response.tables[0].rows) {
            Write-Host "Retrieved $($response.tables[0].rows.Count) log entries from Application Insights"
            return ConvertFrom-ApplicationInsightsResponse -Response $response
        } else {
            Write-Host "No data returned from Application Insights query"
            return @()
        }
    }
    catch {
        Write-Host "Error querying Application Insights: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function ConvertFrom-ApplicationInsightsResponse {
    param($Response)
    
    $columns = $Response.tables[0].columns
    $rows = $Response.tables[0].rows
    
    $alerts = @()
    
    foreach ($row in $rows) {
        $alertData = @{}
        
        # Map columns to values
        for ($i = 0; $i -lt $columns.Count; $i++) {
            $columnName = $columns[$i].name
            $value = $row[$i]
            
            if ($null -ne $value -and $value -ne "") {
                $alertData[$columnName] = $value
            }
        }
        
        # Process and clean up the data
        $processedAlert = @{
            timestamp = if ($alertData.timestamp) { [DateTime]::Parse($alertData.timestamp).ToString('yyyy-MM-ddTHH:mm:ss') } else { "" }
            alertUID = $alertData.AlertUID
            status = $alertData.Status
            client = if ($alertData.Client) { "Client-$($alertData.Client)" } else { "Unknown" }
            device = $alertData.DeviceName
            alertType = if ($alertData.AlertType) { $alertData.AlertType.Trim() } else { "Unknown" }
            summary = Get-AlertSummary -Message $alertData.message
            error = $alertData.ErrorMessage
            ticketId = $alertData.TicketID
            processingTimeSeconds = if ($alertData.ProcessingTime) { [math]::Round([double]$alertData.ProcessingTime, 2) } else { $null }
            operationId = $alertData.operation_Id
            rawMessage = $alertData.message
        }
        
        $alerts += $processedAlert
    }
    
    return $alerts
}

function Get-AlertSummary {
    param([string]$Message)
    
    if (-not $Message) { return "No summary available" }
    
    # Try to extract meaningful summary from log message
    if ($Message -match "Device:\s*([^\s]+)\s+raised Alert:\s*(.+?)(?:\s*-|$)") {
        return "Device: $($matches[1]) - $($matches[2])"
    }
    
    if ($Message -match "Alert.*?:\s*(.+?)(?:\.|$)") {
        return $matches[1]
    }
    
    if ($Message -match "Processing Webhook for Alert") {
        return "Webhook processing"
    }
    
    # Return first 100 characters of message as fallback
    if ($Message.Length -gt 100) {
        return $Message.Substring(0, 100) + "..."
    }
    
    return $Message
}

function Test-ApplicationInsightsConnection {
    try {
        $testStartTime = (Get-Date).AddHours(-1)
        $testEndTime = Get-Date
        
        $testData = Get-ApplicationInsightsData -StartTime $testStartTime -EndTime $testEndTime
        
        Write-Host "Application Insights connection test successful. Retrieved $($testData.Count) entries." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Application Insights connection test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
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
    
    # Convert Application Insights logs to dashboard format
    $alerts = @()
    
    foreach ($log in $LogsData) {
        # Extract alert information from log entry
        $alert = @{
            timestamp = $log.timestamp
            alertUID = $log.customDimensions.alertUID
            status = if ($log.severityLevel -le 2) { "success" } else { "error" }
            client = $log.customDimensions.client
            device = $log.customDimensions.device
            alertType = $log.customDimensions.alertType
            summary = Get-AlertSummary -Message $log.message
            error = if ($log.severityLevel -gt 2) { $log.message } else { $null }
            ticketId = $log.customDimensions.ticketId
            processingTimeSeconds = $log.customDimensions.processingTime
            resolved = $log.customDimensions.resolved -eq 'true'
        }
        
        $alerts += $alert
    }
    
    # Apply filters
    if ($Filters.status -and $Filters.status -ne "all") {
        $alerts = $alerts | Where-Object { $_.status -eq $Filters.status }
    }
    
    if ($Filters.alertType -and $Filters.alertType -ne "all") {
        $alerts = $alerts | Where-Object { $_.alertType -eq $Filters.alertType }
    }
    
    if ($Filters.client -and $Filters.client -ne "all") {
        $alerts = $alerts | Where-Object { $_.client -eq $Filters.client }
    }
    
    # Generate statistics
    $stats = @{
        totalAlerts = $alerts.Count
        successCount = ($alerts | Where-Object { $_.status -eq "success" }).Count
        errorCount = ($alerts | Where-Object { $_.status -eq "error" }).Count
        resolvedCount = ($alerts | Where-Object { $_.resolved -eq $true }).Count
        avgProcessingTime = if ($alerts.Count -gt 0) { 
            [math]::Round(($alerts | Measure-Object -Property processingTimeSeconds -Average).Average, 2) 
        } else { 0 }
    }
    
    return @{
        alerts = $alerts
        stats = $stats
        dateRange = @{
            from = $DateFrom.ToString('yyyy-MM-dd HH:mm:ss')
            to = $DateTo.ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-ApplicationInsightsData',
    'ConvertFrom-ApplicationInsightsResponse', 
    'Get-AlertSummary',
    'Test-ApplicationInsightsConnection',
    'ConvertTo-DashboardData'
)
