# CustomerAlertRoutingHelper.psm1
# Handles customer alert routing decisions - determines if alerts should go to customer email instead of Halo tickets

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CustomerAlertRoutingConfig {
    <#
    .SYNOPSIS
    Retrieves customer alert routing configuration from Azure App Settings.
    
    .DESCRIPTION
    Parses the CUSTOMER_ALERT_ROUTING environment variable which contains a JSON mapping
    of customer names to email addresses and alert routing rules.
    
    Expected Azure App Setting format:
    CUSTOMER_ALERT_ROUTING = {
        "CustomerNameInHalo": {
            "email": "alerts@customer.com",
            "enabled": true,
            "alertTypes": ["perf_disk_usage_ctx", "comp_script_ctx"],
            "excludeAlertTypes": [],
            "severityThreshold": "Low",
            "excludeDeviceTypes": ["Server"],
            "includeAllAlerts": false
        }
    }
    
    .RETURNS
    Hashtable of customer configurations, or empty hashtable if not configured
    
    .EXAMPLE
    $config = Get-CustomerAlertRoutingConfig
    if ($config["Acme Corp"]) {
        Write-Host "Customer routing enabled for Acme Corp"
    }
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if customer alert routing is globally enabled
        $globalEnabled = [bool]::Parse(($env:ENABLE_CUSTOMER_ALERT_ROUTING ?? 'false'))
        
        if (-not $globalEnabled) {
            Write-Host "Customer alert routing is disabled globally (ENABLE_CUSTOMER_ALERT_ROUTING not set to true)"
            return @{}
        }
        
        # Get the routing configuration JSON from environment variable
        $routingConfigJson = $env:CUSTOMER_ALERT_ROUTING
        
        if ([string]::IsNullOrWhiteSpace($routingConfigJson)) {
            Write-Host "No customer alert routing configuration found (CUSTOMER_ALERT_ROUTING not set)"
            return @{}
        }
        
        # Parse the JSON configuration
        $routingConfig = $routingConfigJson | ConvertFrom-Json
        
        # Convert PSCustomObject to hashtable for easier access
        $configHashtable = @{}
        
        foreach ($property in $routingConfig.PSObject.Properties) {
            $customerName = $property.Name
            $customerConfig = $property.Value
            
            # Convert customer config to hashtable
            $customerHashtable = @{
                email              = $customerConfig.email
                enabled            = if ($null -ne $customerConfig.enabled) { [bool]$customerConfig.enabled } else { $true }
                alertTypes         = if ($customerConfig.alertTypes) { @($customerConfig.alertTypes) } else { @() }
                excludeAlertTypes  = if ($customerConfig.excludeAlertTypes) { @($customerConfig.excludeAlertTypes) } else { @() }
                severityThreshold  = if ($customerConfig.severityThreshold) { $customerConfig.severityThreshold } else { "Low" }
                excludeDeviceTypes = if ($customerConfig.excludeDeviceTypes) { @($customerConfig.excludeDeviceTypes) } else { @() }
                includeAllAlerts   = if ($null -ne $customerConfig.includeAllAlerts) { [bool]$customerConfig.includeAllAlerts } else { $false }
            }
            
            $configHashtable[$customerName] = $customerHashtable
        }
        
        Write-Host "Loaded customer alert routing configuration for $($configHashtable.Count) customer(s)"
        return $configHashtable
    }
    catch {
        Write-Warning "Error loading customer alert routing configuration: $($_.Exception.Message)"
        return @{}
    }
}

function Test-ShouldRouteToCustomer {
    <#
    .SYNOPSIS
    Determines if an alert should be routed to a customer instead of creating a Halo ticket.
    
    .DESCRIPTION
    Checks customer routing rules from Azure App Settings to determine if this alert should
    be sent directly to the customer via email instead of creating a ticket.
    
    .PARAMETER CustomerName
    The Halo client name (e.g., "Acme Corp", "Smith & Associates")
    
    .PARAMETER AlertType
    The Datto alert type context (e.g., "perf_disk_usage_ctx", "comp_script_ctx")
    
    .PARAMETER AlertSeverity
    The alert severity/priority (e.g., "Critical", "High", "Low", "Information")
    
    .PARAMETER DeviceType
    The device type: "Server", "PC", or "Unknown"
    
    .RETURNS
    Hashtable with:
    - ShouldRoute: Boolean indicating if alert should go to customer
    - CustomerEmail: Email address to send to (if routing)
    - Reason: Explanation of routing decision
    
    .EXAMPLE
    $decision = Test-ShouldRouteToCustomer -CustomerName "Acme Corp" -AlertType "perf_disk_usage_ctx" -AlertSeverity "Low" -DeviceType "PC"
    if ($decision.ShouldRoute) {
        Send-AlertToCustomer -Email $decision.CustomerEmail -Alert $alert
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CustomerName,
        
        [Parameter(Mandatory)]
        [string]$AlertType,
        
        [Parameter(Mandatory)]
        [string]$AlertSeverity,
        
        [Parameter(Mandatory)]
        [string]$DeviceType
    )
    
    $result = @{
        ShouldRoute   = $false
        CustomerEmail = $null
        Reason        = "No routing configured"
    }
    
    try {
        # Get routing configuration
        $routingConfig = Get-CustomerAlertRoutingConfig
        
        if ($routingConfig.Count -eq 0) {
            $result.Reason = "Customer alert routing not enabled or not configured"
            Write-Host "No customer routing configuration available"
            return $result
        }
        
        # Check if this customer has routing configured
        $customerConfig = $routingConfig[$CustomerName]
        
        if (-not $customerConfig) {
            $result.Reason = "No routing configured for customer '$CustomerName'"
            Write-Host "No routing rule found for customer: $CustomerName"
            return $result
        }
        
        # Check if routing is enabled for this customer
        if (-not $customerConfig.enabled) {
            $result.Reason = "Routing is disabled for customer '$CustomerName'"
            Write-Host "Routing disabled for customer: $CustomerName"
            return $result
        }
        
        # Validate email address exists
        if ([string]::IsNullOrWhiteSpace($customerConfig.email)) {
            $result.Reason = "No email address configured for customer '$CustomerName'"
            Write-Warning "Customer routing enabled but no email configured for: $CustomerName"
            return $result
        }
        
        Write-Host "=== Customer Alert Routing Check for '$CustomerName' ==="
        Write-Host "Alert Type: $AlertType | Severity: $AlertSeverity | Device: $DeviceType"
        
        # Check if this is an "includeAllAlerts" customer (route everything)
        if ($customerConfig.includeAllAlerts) {
            $result.ShouldRoute = $true
            $result.CustomerEmail = $customerConfig.email
            $result.Reason = "Customer configured to receive ALL alerts"
            Write-Host "✓ Routing to customer: includeAllAlerts enabled"
            return $result
        }
        
        # Check device type exclusions
        if ($customerConfig.excludeDeviceTypes -contains $DeviceType) {
            $result.Reason = "Device type '$DeviceType' is excluded from customer routing"
            Write-Host "✗ Not routing: Device type excluded"
            return $result
        }
        
        # Check alert type exclusions (takes priority over inclusions)
        if ($customerConfig.excludeAlertTypes -contains $AlertType) {
            $result.Reason = "Alert type '$AlertType' is explicitly excluded from customer routing"
            Write-Host "✗ Not routing: Alert type explicitly excluded"
            return $result
        }
        
        # Check if alert type matches inclusion list
        if ($customerConfig.alertTypes.Count -gt 0) {
            if ($customerConfig.alertTypes -notcontains $AlertType) {
                $result.Reason = "Alert type '$AlertType' not in customer's alert type inclusion list"
                Write-Host "✗ Not routing: Alert type not in inclusion list"
                return $result
            }
        }
        else {
            # No specific alert types configured and not includeAllAlerts
            $result.Reason = "No alert types configured for customer routing (and includeAllAlerts is false)"
            Write-Host "✗ Not routing: No alert types configured"
            return $result
        }
        
        # Check severity threshold (optional filter)
        $severityLevels = @{
            "Critical"    = 4
            "High"        = 3
            "Moderate"    = 2
            "Low"         = 1
            "Information" = 0
        }
        
        $alertSeverityValue = $severityLevels[$AlertSeverity]
        $thresholdValue = $severityLevels[$customerConfig.severityThreshold]
        
        if ($null -ne $alertSeverityValue -and $null -ne $thresholdValue) {
            if ($alertSeverityValue -lt $thresholdValue) {
                $result.Reason = "Alert severity '$AlertSeverity' below customer threshold '$($customerConfig.severityThreshold)'"
                Write-Host "✗ Not routing: Severity below threshold"
                return $result
            }
        }
        
        # All checks passed - route to customer
        $result.ShouldRoute = $true
        $result.CustomerEmail = $customerConfig.email
        $result.Reason = "Alert matches customer routing rules"
        Write-Host "✓ ROUTING TO CUSTOMER: $($customerConfig.email)"
        
        return $result
    }
    catch {
        Write-Warning "Error checking customer routing: $($_.Exception.Message)"
        $result.Reason = "Error: $($_.Exception.Message)"
        return $result
    }
}

function New-CustomerAlertEmail {
    <#
    .SYNOPSIS
    Generates a customer-friendly email body for alert forwarding.
    
    .DESCRIPTION
    Creates an HTML email body that translates technical Datto alerts into
    customer-friendly language with clear action items.
    
    .PARAMETER Alert
    The Datto alert object
    
    .PARAMETER AlertMessage
    The raw alert message from Datto
    
    .PARAMETER DeviceName
    The name of the affected device
    
    .PARAMETER AlertType
    The friendly alert type name
    
    .RETURNS
    HTML-formatted email body string
    
    .EXAMPLE
    $emailBody = New-CustomerAlertEmail -Alert $alert -AlertMessage $msg -DeviceName "PC01" -AlertType "Disk Usage"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Alert,
        
        [Parameter(Mandatory)]
        [string]$AlertMessage,
        
        [Parameter(Mandatory)]
        [string]$DeviceName,
        
        [Parameter(Mandatory)]
        [string]$AlertType
    )
    
    try {
        # Get email template from configuration or use default
        $template = Get-AlertingConfig -Path "CustomerAlertRouting.EmailTemplate"
        
        if (-not $template) {
            # Default customer-friendly template
            $template = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .alert-box { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .alert-box.critical { background-color: #f8d7da; border-left-color: #dc3545; }
        .alert-box.warning { background-color: #fff3cd; border-left-color: #ffc107; }
        .alert-box.info { background-color: #d1ecf1; border-left-color: #17a2b8; }
        .device-info { background-color: #f8f9fa; padding: 10px; margin: 15px 0; border-radius: 5px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 0.9em; color: #666; }
        h2 { color: #0066cc; }
        strong { color: #000; }
    </style>
</head>
<body>
    <h2>System Alert Notification</h2>
    
    <div class="alert-box {SEVERITY_CLASS}">
        <strong>Alert Type:</strong> {ALERT_TYPE}<br>
        <strong>Severity:</strong> {SEVERITY}<br>
        <strong>Device:</strong> {DEVICE_NAME}
    </div>
    
    <h3>Alert Details</h3>
    <p>{ALERT_MESSAGE}</p>
    
    <div class="device-info">
        <strong>Affected System:</strong> {DEVICE_NAME}<br>
        <strong>Alert Time:</strong> {ALERT_TIME}
    </div>
    
    <h3>What This Means</h3>
    <p>Our monitoring system has detected an issue that may require attention. {ACTION_REQUIRED}</p>
    
    <h3>Recommended Action</h3>
    <p>{RECOMMENDED_ACTION}</p>
    
    <div class="footer">
        <p>This is an automated alert from your IT monitoring system. If you need assistance, please contact your IT support team.</p>
        <p><em>Alert ID: {ALERT_UID}</em></p>
    </div>
</body>
</html>
"@
        }
        
        # Get severity class for styling
        $priority = $Alert.priority ?? "Information"
        $severityClass = switch ($priority) {
            "Critical" { "critical" }
            "High" { "critical" }
            "Moderate" { "warning" }
            "Low" { "warning" }
            default { "info" }
        }
        
        # Generate customer-friendly explanations based on alert type
        $actionRequired = "Please review the details below."
        $recommendedAction = "If this issue persists, please contact your IT support team."
        
        switch -Wildcard ($AlertType) {
            "*Disk Usage*" {
                $actionRequired = "Your disk space is running low and may affect system performance."
                $recommendedAction = "Please delete unnecessary files or contact IT to expand storage capacity."
            }
            "*Memory Usage*" {
                $actionRequired = "System memory usage is high, which may slow down your computer."
                $recommendedAction = "Try closing unused applications or restart your computer. Contact IT if the issue persists."
            }
            "*Offline*" {
                $actionRequired = "This device appears to be offline or unreachable."
                $recommendedAction = "Please ensure the device is powered on and connected to the network."
            }
            "*Patch*" {
                $actionRequired = "Windows updates have failed to install properly."
                $recommendedAction = "Your IT team will review this issue. Please ensure the device remains powered on during business hours."
            }
            "*Event Log*" {
                $actionRequired = "The system has logged an event that requires review."
                $recommendedAction = "Your IT team will investigate this alert. No immediate action is required from you."
            }
            default {
                $actionRequired = "A system monitoring alert has been triggered."
                $recommendedAction = "Your IT team will review this alert. If you're experiencing issues, please contact IT support."
            }
        }
        
        # Replace template placeholders
        $emailBody = $template `
            -replace '{ALERT_TYPE}', [System.Web.HttpUtility]::HtmlEncode($AlertType) `
            -replace '{SEVERITY}', [System.Web.HttpUtility]::HtmlEncode($priority) `
            -replace '{SEVERITY_CLASS}', $severityClass `
            -replace '{DEVICE_NAME}', [System.Web.HttpUtility]::HtmlEncode($DeviceName) `
            -replace '{ALERT_MESSAGE}', [System.Web.HttpUtility]::HtmlEncode($AlertMessage) `
            -replace '{ALERT_TIME}', (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') `
            -replace '{ACTION_REQUIRED}', $actionRequired `
            -replace '{RECOMMENDED_ACTION}', $recommendedAction `
            -replace '{ALERT_UID}', [System.Web.HttpUtility]::HtmlEncode($Alert.alertUID)
        
        return $emailBody
    }
    catch {
        Write-Warning "Error generating customer alert email: $($_.Exception.Message)"
        # Return basic fallback
        return "<html><body><h2>System Alert</h2><p>$AlertMessage</p><p>Device: $DeviceName</p></body></html>"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-CustomerAlertRoutingConfig',
    'Test-ShouldRouteToCustomer',
    'New-CustomerAlertEmail'
)
