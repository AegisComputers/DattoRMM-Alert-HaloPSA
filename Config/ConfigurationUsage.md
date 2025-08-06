# Configuration Management Example Usage

## Basic Configuration Access

```powershell
# Get a specific configuration value
$patchThreshold = Get-AlertingConfig -Path "AlertThresholds.PatchAlertCount"
# Returns: 2

# Get business hours start time
$startTime = Get-AlertingConfig -Path "BusinessHours.StartTime"
# Returns: "09:00"

# Get entire priority mapping
$priorityMap = Get-AlertingConfig -Path "PriorityMapping"
# Returns: hashtable with Critical=4, High=4, etc.

# Get a value with a default fallback
$customValue = Get-AlertingConfig -Path "NonExistent.Setting" -DefaultValue "default_value"
# Returns: "default_value" since the path doesn't exist
```

## Runtime Configuration Changes

```powershell
# Change patch alert threshold
Set-AlertingConfig -Path "AlertThresholds.PatchAlertCount" -Value 3

# Change business hours and persist to file
Set-AlertingConfig -Path "BusinessHours.StartTime" -Value "08:30" -Persist

# Update customer notification email template
$newTemplate = "<p>Your disk is getting full. Please clean up files.</p>"
Set-AlertingConfig -Path "CustomerNotifications.DiskUsage.EmailTemplate" -Value $newTemplate -Persist
```

## Business Hours Helper

```powershell
# Get business hours configuration with helper methods
$businessHours = Get-BusinessHoursConfig

# Check if current time is business hours
$isBusinessHours = $businessHours.IsBusinessHours.Invoke([DateTime]::UtcNow)

# Check if a day is a weekend
$isWeekend = $businessHours.IsWeekend.Invoke("Saturday")
```

## Configuration Validation

```powershell
# Validate current configuration
$issues = Test-AlertingConfiguration

if ($issues.Count -eq 0) {
    Write-Host "Configuration is valid!" -ForegroundColor Green
} else {
    Write-Warning "Configuration issues found:"
    $issues | ForEach-Object { Write-Warning "  - $_" }
}
```

## Configuration File Structure

The `AlertingConfig.json` file contains the following main sections:

### AlertThresholds
- `PatchAlertCount`: Number of patch alerts before creating ticket (default: 2)
- `HtmlBodyMaxLength`: Maximum HTML body size in characters (default: 3000000)
- `RelatedAlertWindowMinutes`: Minutes to consider alerts as related (default: 5)
- `HaloAlertHistoryDays`: Days of alert history to maintain (default: 30)
- `ReoccurringTicketHours`: Hours before creating reoccurring ticket (default: 24)

### BusinessHours
- `StartTime`: Business day start time in HH:mm format (default: "09:00")
- `EndTime`: Business day end time in HH:mm format (default: "17:30")
- `TimeZone`: Windows timezone identifier (default: "GMT Standard Time")
- `WorkDays`: Array of working days (default: Mon-Fri)
- `SkipWeekendsForHyperV`: Skip HyperV alerts on weekends (default: true)

### Storage
- `TableName`: Azure table storage name (default: "DevicePatchAlerts")
- `PartitionKey`: Storage partition key (default: "DeviceAlert")
- `StorageAccountName`: Azure storage account name

### TicketDefaults
- `TicketTypeId`: Default Halo ticket type ID (default: 8)
- `Category1`: Default ticket category (default: "Datto Alert")
- `SetTicketResponded`: Mark tickets as responded (default: true)
- `DefaultSiteId`: Fallback site ID (default: 286)
- `DefaultClientName`: Fallback client name (default: "Aegis Internal")

### PriorityMapping
Maps Datto alert priorities to Halo priority IDs:
- `Critical`: "4"
- `High`: "4"
- `Moderate`: "4"
- `Low`: "4"
- `Information`: "4"

### CustomerNotifications
Email templates and settings for customer notifications:
- `DiskUsage.EmailTemplate`: HTML template for disk usage alerts
- `DiskUsage.SupportPhone`: Support phone number

### WindowsErrorCodes
Mapping of Windows error codes to human-readable descriptions

## Environment-Specific Configuration

You can create environment-specific configuration files:

- `Config/Development.json` - Development settings
- `Config/Staging.json` - Staging environment settings  
- `Config/Production.json` - Production settings

Load specific environments using:
```powershell
Initialize-AlertingConfiguration -ConfigFilePath "Config/Production.json"
```

## Best Practices

1. **Always use default values** when calling `Get-AlertingConfig` to ensure fallback behavior
2. **Validate configuration** on startup using `Test-AlertingConfiguration`
3. **Use the `-Persist` flag** only when you want to save changes permanently
4. **Keep environment-specific values** in separate config files
5. **Document any new configuration paths** you add to the system

## Troubleshooting

If configuration loading fails:
1. Check that the JSON file is valid JSON syntax
2. Ensure the Config directory exists
3. Verify file permissions
4. Check Azure Function logs for detailed error messages

The system will automatically create a default configuration file if none exists.
