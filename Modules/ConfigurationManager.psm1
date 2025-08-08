<#
.SYNOPSIS
Configuration Management Module for DattoRMM-Alert-HaloPSA

.DESCRIPTION
This module provides centralized configuration management for the DattoRMM-Alert-HaloPSA system.
It loads configuration from JSON files and provides easy access to all settings throughout the application.

.AUTHOR
Oliver Perring - Aegis Computer Maintenance Ltd

.VERSION
1.0.0
#>

Set-StrictMode -Version Latest

# Global variable to store the loaded configuration
$script:LoadedConfig = $null
$script:ConfigPath = $null

function Initialize-AlertingConfiguration {
    <#
    .SYNOPSIS
    Initializes the configuration system by loading the main configuration file.
    
    .DESCRIPTION
    Loads the AlertingConfig.json file and makes all configuration values available
    throughout the application. This should be called once during application startup.
    
    .PARAMETER ConfigFilePath
    Optional path to a specific configuration file. If not provided, will look for
    AlertingConfig.json in the Config directory relative to the script root.
    
    .EXAMPLE
    Initialize-AlertingConfiguration
    
    .EXAMPLE
    Initialize-AlertingConfiguration -ConfigFilePath "C:\Custom\MyConfig.json"
    #>
    param(
        [string]$ConfigFilePath
    )
    
    try {
        # Determine config file path
        if (-not $ConfigFilePath) {
            $script:ConfigPath = Join-Path $PSScriptRoot "..\Config\AlertingConfig.json"
        } else {
            $script:ConfigPath = $ConfigFilePath
        }
        
        # Check if config file exists
        if (-not (Test-Path $script:ConfigPath)) {
            Write-Warning "Configuration file not found at: $script:ConfigPath"
            Write-Host "Creating default configuration file..."
            New-DefaultConfigurationFile -Path $script:ConfigPath
        }
        
        # Load the configuration
        $script:LoadedConfig = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        Write-Host "Configuration loaded successfully from: $script:ConfigPath"
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize configuration: $($_.Exception.Message)"
        return $false
    }
}

function Get-AlertingConfig {
    <#
    .SYNOPSIS
    Retrieves configuration values from the loaded configuration.
    
    .DESCRIPTION
    Provides access to configuration values using dot notation path strings.
    If no path is specified, returns the entire configuration object.
    
    .PARAMETER Path
    Dot-notation path to the specific configuration value (e.g., "AlertThresholds.PatchAlertCount")
    
    .PARAMETER DefaultValue
    Default value to return if the specified path is not found
    
    .EXAMPLE
    Get-AlertingConfig -Path "AlertThresholds.PatchAlertCount"
    Returns: 2
    
    .EXAMPLE
    Get-AlertingConfig -Path "BusinessHours.StartTime"
    Returns: "09:00"
    
    .EXAMPLE
    Get-AlertingConfig
    Returns: [entire configuration object]
    
    .EXAMPLE
    Get-AlertingConfig -Path "NonExistent.Setting" -DefaultValue "default"
    Returns: "default"
    #>
    param(
        [string]$Path,
        $DefaultValue = $null
    )
    
    # Ensure configuration is loaded
    if (-not $script:LoadedConfig) {
        Write-Warning "Configuration not loaded. Initializing with default settings..."
        if (-not (Initialize-AlertingConfiguration)) {
            Write-Error "Failed to initialize configuration"
            return $DefaultValue
        }
    }
    
    # If no path specified, return entire config
    if (-not $Path) {
        return $script:LoadedConfig
    }
    
    try {
        # Navigate through the configuration using the dot notation path
        $current = $script:LoadedConfig
        $pathParts = $Path.Split('.')
        
        foreach ($part in $pathParts) {
            if ($current -and ($current | Get-Member -Name $part -MemberType Properties)) {
                $current = $current.$part
            } else {
                Write-Debug "Configuration path '$Path' not found, returning default value"
                return $DefaultValue
            }
        }
        
        return $current
    }
    catch {
        Write-Warning "Error accessing configuration path '$Path': $($_.Exception.Message)"
        return $DefaultValue
    }
}

function Set-AlertingConfig {
    <#
    .SYNOPSIS
    Updates a configuration value and optionally saves it to the file.
    
    .DESCRIPTION
    Allows runtime modification of configuration values. Changes can be persisted
    to the configuration file or kept in memory only.
    
    .PARAMETER Path
    Dot-notation path to the configuration value to update
    
    .PARAMETER Value
    New value to set
    
    .PARAMETER Persist
    If specified, saves the updated configuration back to the file
    
    .EXAMPLE
    Set-AlertingConfig -Path "AlertThresholds.PatchAlertCount" -Value 3
    
    .EXAMPLE
    Set-AlertingConfig -Path "BusinessHours.StartTime" -Value "08:00" -Persist
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        $Value,
        [switch]$Persist
    )
    
    # Ensure configuration is loaded
    if (-not $script:LoadedConfig) {
        Initialize-AlertingConfiguration
    }
    
    try {
        # Navigate to the parent object and set the value
        $pathParts = $Path.Split('.')
        $current = $script:LoadedConfig
        
        # Navigate to the parent of the target property
        for ($i = 0; $i -lt ($pathParts.Length - 1); $i++) {
            $part = $pathParts[$i]
            if (-not ($current | Get-Member -Name $part -MemberType Properties)) {
                # Create missing intermediate objects
                $current | Add-Member -NotePropertyName $part -NotePropertyValue ([PSCustomObject]@{})
            }
            $current = $current.$part
        }
        
        # Set the final property
        $finalProperty = $pathParts[-1]
        if ($current | Get-Member -Name $finalProperty -MemberType Properties) {
            $current.$finalProperty = $Value
        } else {
            $current | Add-Member -NotePropertyName $finalProperty -NotePropertyValue $Value
        }
        
        Write-Host "Configuration updated: $Path = $Value"
        
        # Persist to file if requested
        if ($Persist) {
            Save-AlertingConfiguration
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to set configuration value '$Path': $($_.Exception.Message)"
        return $false
    }
}

function Save-AlertingConfiguration {
    <#
    .SYNOPSIS
    Saves the current configuration to the configuration file.
    
    .DESCRIPTION
    Persists any runtime configuration changes back to the JSON configuration file.
    
    .EXAMPLE
    Save-AlertingConfiguration
    #>
    
    if (-not $script:LoadedConfig -or -not $script:ConfigPath) {
        Write-Error "No configuration loaded or config path not set"
        return $false
    }
    
    try {
        $script:LoadedConfig | ConvertTo-Json -Depth 10 | Set-Content $script:ConfigPath -Encoding UTF8
        Write-Host "Configuration saved to: $script:ConfigPath"
        return $true
    }
    catch {
        Write-Error "Failed to save configuration: $($_.Exception.Message)"
        return $false
    }
}

function New-DefaultConfigurationFile {
    <#
    .SYNOPSIS
    Creates a default configuration file at the specified path.
    
    .PARAMETER Path
    Path where the default configuration file should be created
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    # Ensure the directory exists
    $directory = Split-Path $Path -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    
    # Default configuration structure
    $defaultConfig = @{
        AlertThresholds = @{
            PatchAlertCount = 2
            HtmlBodyMaxLength = 3000000
            RelatedAlertWindowMinutes = 5
            HaloAlertHistoryDays = 30
            ReoccurringTicketHours = 24
        }
        BusinessHours = @{
            StartTime = "09:00"
            EndTime = "17:30"
            TimeZone = "GMT Standard Time"
            WorkDays = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
            SkipWeekendsForHyperV = $true
        }
        Storage = @{
            TableName = "DevicePatchAlerts"
            PartitionKey = "DeviceAlert"
            StorageAccountName = "dattohaloalertsstgnirab"
        }
        TicketDefaults = @{
            TicketTypeId = 8
            Category1 = "Datto Alert"
            SetTicketResponded = $true
            DefaultSiteId = 286
            DefaultClientName = "Aegis Internal"
        }
        PriorityMapping = @{
            Critical = "4"
            High = "4"
            Moderate = "4"
            Low = "4"
            Information = "4"
        }
        AlertConsolidation = @{
            EnableConsolidation = $true
            ConsolidationWindowHours = 24
            ConsolidatableAlertTypes = @(
                "An account failed to log on",
                "Account lockout", 
                "Multiple failed login attempts",
                "Security audit failure"
            )
            ConsolidationSearchStatuses = @(
                "Awaiting Customer Reply (AS)",
                "Awaiting Customer Reply (CS)", 
                "New",
                "Agent Assigned",
                "Work In Progress",
                "Awaiting 3rd Party Action",
                "Project",
                "Awaiting Approval",
                "Awaiting Availability",
                "Awaiting Deletion",
                "Awaiting Client Confirmation",
                "Awaiting Information",
                "Awaiting Invoice Amendments",
                "Awaiting Parts",
                "Awaiting Quote",
                "Awaiting Reply",
                "Awaiting Fix or Change",
                "Awaiting Schedule",
                "Awaiting Delivery",
                "Awaiting Time Adding",
                "Dispatched (DHL)",
                "Parked",
                "Scheduled",
                "Awaiting for Supplier Information",
                "Awaiting Closure (Complete)",
                "Workflow in Progress",
                "Re-Opened Ticket",
                "Leaver",
                "Joiner",
                "Change Request: Approval Pending",
                "Change Request: Approved and Scheduled",
                "On Hold - Inactive"
            )
            MaxConsolidationCount = 500
            ConsolidationNoteTemplate = "Additional {AlertType} alert detected at {Timestamp}. Total occurrences: {Count}"
        }
        Debugging = @{
            EnableVerboseLogging = $false
            LogTicketCreationDetails = $true
            EnablePerformanceMetrics = $false
        }
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
}

function Get-BusinessHoursConfig {
    <#
    .SYNOPSIS
    Helper function to get business hours configuration with computed values.
    
    .DESCRIPTION
    Returns business hours configuration with additional computed properties
    for easier use in business logic.
    #>
    
    $businessHours = Get-AlertingConfig -Path "BusinessHours"
    if (-not $businessHours) {
        return $null
    }
    
    # Add computed properties
    $businessHours | Add-Member -NotePropertyName "IsWeekend" -NotePropertyValue {
        param($DayOfWeek)
        return $DayOfWeek -notin $businessHours.WorkDays
    } -Force
    
    $businessHours | Add-Member -NotePropertyName "IsBusinessHours" -NotePropertyValue {
        param($DateTime)
        $timeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($businessHours.TimeZone)
        $localTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($DateTime, $timeZone)
        
        $startTime = [datetime]::ParseExact($businessHours.StartTime, "HH:mm", $null)
        $endTime = [datetime]::ParseExact($businessHours.EndTime, "HH:mm", $null)
        
        $currentTime = $localTime.TimeOfDay
        $isWorkDay = $localTime.DayOfWeek.ToString() -in $businessHours.WorkDays
        $isInHours = $currentTime -ge $startTime.TimeOfDay -and $currentTime -lt $endTime.TimeOfDay
        
        return $isWorkDay -and $isInHours
    } -Force
    
    return $businessHours
}

function Test-AlertingConfiguration {
    <#
    .SYNOPSIS
    Validates the current configuration for common issues.
    
    .DESCRIPTION
    Performs validation checks on the loaded configuration and reports any
    potential issues or inconsistencies.
    
    .EXAMPLE
    Test-AlertingConfiguration
    #>
    
    $issues = @()
    
    # Check if configuration is loaded
    if (-not $script:LoadedConfig) {
        $issues += "Configuration not loaded"
        return $issues
    }
    
    # Validate required sections
    $requiredSections = @("AlertThresholds", "BusinessHours", "Storage", "TicketDefaults")
    foreach ($section in $requiredSections) {
        if (-not (Get-AlertingConfig -Path $section)) {
            $issues += "Missing required configuration section: $section"
        }
    }
    
    # Validate specific values
    $patchCount = Get-AlertingConfig -Path "AlertThresholds.PatchAlertCount"
    if ($patchCount -lt 1) {
        $issues += "PatchAlertCount must be at least 1"
    }
    
    $maxLength = Get-AlertingConfig -Path "AlertThresholds.HtmlBodyMaxLength"
    if ($maxLength -lt 100000) {
        $issues += "HtmlBodyMaxLength seems too small (should be at least 100KB)"
    }
    
    # Validate business hours
    $startTime = Get-AlertingConfig -Path "BusinessHours.StartTime"
    $endTime = Get-AlertingConfig -Path "BusinessHours.EndTime"
    if ($startTime -and $endTime) {
        try {
            $start = [datetime]::ParseExact($startTime, "HH:mm", $null)
            $end = [datetime]::ParseExact($endTime, "HH:mm", $null)
            if ($start -ge $end) {
                $issues += "Business hours start time must be before end time"
            }
        }
        catch {
            $issues += "Invalid business hours time format (should be HH:mm)"
        }
    }
    
    if ($issues.Count -eq 0) {
        Write-Host "Configuration validation passed" -ForegroundColor Green
    } else {
        Write-Warning "Configuration validation found $($issues.Count) issues:"
        foreach ($issue in $issues) {
            Write-Warning "  - $issue"
        }
    }
    
    return $issues
}

# Export the public functions
Export-ModuleMember -Function @(
    'Initialize-AlertingConfiguration',
    'Get-AlertingConfig', 
    'Set-AlertingConfig',
    'Save-AlertingConfiguration',
    'Get-BusinessHoursConfig',
    'Test-AlertingConfiguration'
)
