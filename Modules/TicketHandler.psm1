# TicketHandler.psm1
# Enhanced error handling and validation

[CmdletBinding()]
param()

# Set strict mode for better error detection
Set-StrictMode -Version Latest

# Set up error handling preferences
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Initialize module with validation
try {
    # Validate required environment variables
    $requiredEnvVars = @(
        'HaloClientID', 'HaloClientSecret', 'HaloURL', 'HaloTicketStatusID',
        'HaloCustomAlertTypeField', 'HaloTicketType', 'DattoURL', 'DattoKey', 'DattoSecretKey'
    )
    
    $missingVars = @()
    foreach ($var in $requiredEnvVars) {
        if (-not (Get-ChildItem Env:$var -ErrorAction SilentlyContinue)) {
            $missingVars += $var
        }
    }
    
    if ($missingVars.Count -gt 0) {
        Write-Warning "Missing required environment variables: $($missingVars -join ', ')"
        Write-Warning "Some functions may not work correctly without these variables."
    }
    
    # Set environment variables and local variables with validation
    $storageAccountName = Get-AlertingConfig -Path "Storage.StorageAccountName" -DefaultValue "dattohaloalertsstgnirab"
    $storageAccountKey = $env:strKey
    $tableName = Get-AlertingConfig -Path "Storage.TableName" -DefaultValue "DevicePatchAlerts"

    # Validate storage configuration
    if (-not $storageAccountKey) {
        Write-Warning "Storage account key is not set. Please set the environment variable 'strKey'."
        Write-Warning "Storage-dependent functions may not work correctly."
        # Don't stop module loading, just warn
    }

    # Halo Vars with validation
    $HaloClientID = $env:HaloClientID
    $HaloClientSecret = $env:HaloClientSecret
    $HaloURL = $env:HaloURL
    $HaloTicketStatusID = $env:HaloTicketStatusID
    $HaloCustomAlertTypeField = $env:HaloCustomAlertTypeField
    $HaloTicketType = $env:HaloTicketType
    $HaloReocurringStatus = $env:HaloReocurringStatus

    # Datto Vars with validation
    $DattoURL = $env:DattoURL
    $DattoKey = $env:DattoKey
    $DattoSecretKey = $env:DattoSecretKey
    $DattoAlertUIDField = $env:DattoAlertUIDField

    # Connect to Azure Storage with error handling
    if ($storageAccountKey) {
        try {
            $context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey -ErrorAction Stop
            $table = Get-StorageTable -Context $context -TableName $tableName -ErrorAction Stop
            Write-Verbose "Successfully connected to Azure Storage"
        }
        catch {
            Write-Warning "Failed to connect to Azure Storage: $($_.Exception.Message)"
            Write-Warning "Storage-dependent functions may not work correctly."
        }
    } else {
        Write-Verbose "Skipping Azure Storage connection due to missing credentials"
    }
}
catch {
    Write-Error "Failed to initialize TicketHandler module: $($_.Exception.Message)" -ErrorAction Stop
}

## Global cache for online error lookups
$global:OnlineErrorCache = @{}

function New-HaloTicketWithFallback {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $HaloTicketCreate
    )

    begin {
        Write-Verbose "Starting ticket creation with fallback logic"
        $retryCount = 0
        $maxRetries = Get-AlertingConfig -Path "ErrorHandling.MaxRetryAttempts" -DefaultValue 3
        $retryDelay = Get-AlertingConfig -Path "ErrorHandling.RetryDelaySeconds" -DefaultValue 2
    }

    process {
        do {
            try {
                Write-Verbose "Attempting to create Halo ticket (attempt $($retryCount + 1))"
                
                # Validate ticket object structure
                if (-not $HaloTicketCreate.summary) {
                    throw "Ticket summary is required but missing"
                }
                
                $Ticket = New-HaloTicket -Ticket $HaloTicketCreate -ErrorAction Stop
                Write-Host "Ticket created successfully with ID: $($Ticket.id)"
                return $Ticket
            }
            catch {
                $retryCount++
                $errorMessage = $_.Exception.Message
                Write-Warning "Failed to create Halo ticket (attempt $retryCount): $errorMessage"
                
                # Check if it's a timeout error for fallback logic
                if ($errorMessage -like "*504*" -or $errorMessage -like "*timeout*" -or $errorMessage -like "*Gateway Time-out*") {
                    Write-Host "Attempting to create ticket with minimal details due to timeout..."
                    
                    try {
                        $HaloTicketCreateFallback = $HaloTicketCreate.PSObject.Copy()
                        
                        # Create a very basic ticket with essential information only
                        $AlertUID = ($HaloTicketCreate.customfields | Where-Object { $_.id -eq $env:DattoAlertUIDField }).value
                        $TicketSummary = $HaloTicketCreate.summary
                        
                        # Use helper function to create minimal content
                        $MinimalContent = New-MinimalTicketContent -TicketSummary $TicketSummary -AlertUID $AlertUID
                        $HaloTicketCreateFallback.details_html = $MinimalContent
                        
                        $Ticket = New-HaloTicket -Ticket $HaloTicketCreateFallback -ErrorAction Stop
                        Write-Host "Fallback ticket created successfully with ID: $($Ticket.id)"
                        return $Ticket
                    }
                    catch {
                        Write-Error "Failed to create fallback ticket: $($_.Exception.Message)"
                        if ($retryCount -ge $maxRetries) {
                            throw
                        }
                    }
                }
                else {
                    # For non-timeout errors, check if we should retry
                    if ($retryCount -ge $maxRetries) {
                        Write-Error "Maximum retry attempts ($maxRetries) reached. Giving up."
                        throw
                    }
                }
                
                if ($retryCount -lt $maxRetries) {
                    Write-Host "Waiting $retryDelay seconds before retry..."
                    Start-Sleep -Seconds $retryDelay
                }
            }
        } while ($retryCount -lt $maxRetries)
        
        # If we get here, all retries failed
        throw "Failed to create ticket after $maxRetries attempts"
    }
}

function New-MinimalTicketContent {
    param(
        [string]$TicketSummary,
        [string]$AlertUID
    )
    
    return @"
<table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%;" bgcolor="#333333" width="100%">
<tbody><tr><td style="width: 100%; margin: 0; padding: 16px;" align="left" bgcolor="#333333" width="100%">
<table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color:#222222;">
<tr><td style="padding: 15px; font-family: sans-serif; font-size: 15px; line-height: 20px; color: #ffffff;">
<h3 style="color: #ffffff; margin-top: 0;">Alert Created - API Timeout Recovery</h3>
<table style="width: 100%; border-collapse: collapse; margin: 10px 0; color: #ffffff;">
<tr style="background-color: #333333;"><td style="padding: 8px; font-weight: bold; color: #ffffff;">Summary:</td><td style="padding: 8px; color: #ffffff;">$TicketSummary</td></tr>
<tr><td style="padding: 8px; font-weight: bold; color: #ffffff;">Alert UID:</td><td style="padding: 8px; color: #ffffff;">$AlertUID</td></tr>
<tr style="background-color: #333333;"><td style="padding: 8px; font-weight: bold; color: #ffffff;">Status:</td><td style="padding: 8px; color: #ffffff;">Ticket created with minimal content due to API timeout.</td></tr>
</table>
<div style="background-color: #333333; padding: 10px; margin: 10px 0; border-left: 3px solid #ff9800; color: #ffffff;">
<strong style="color: #ffffff;">Note:</strong> Original alert content was too large for API transmission. 
Please check the original alert in Datto RMM using the Alert UID above for complete details.
</div>
</td></tr></table></td></tr></tbody></table>
"@
}

function Get-WindowsErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorCode
    )

    if ($ErrorCode -like "*Aborted*") {
        return "The operation was aborted."
    }

    if ($ErrorCode -like "*AccessDenied*") {
		return "Access is denied."
	}

    #if ($ErrorCode -isnot [int]) {
	#	return "ErrorCode must be an integer. Something went wrong when applying patch!"
	#}

    # Check for a custom error message first
    try {
        $customErrorMessage = Get-CustomErrorMessage -ErrorCode $ErrorCode
        if ($customErrorMessage) {
            return $customErrorMessage
        }
    } catch {
        Write-Debug "Failed to find custom error code entry for code $ErrorCode. Error: $_"
        $errorMessage = "Unknown error code or not a Win32 error."
    }

    # Try using Win32Exception to get a message
    try {
        $exception = New-Object System.ComponentModel.Win32Exception($ErrorCode)
        $errorMessage = $exception.Message
    } catch {
        Write-Debug "Failed to create Win32Exception for code $ErrorCode. Error: $_"
        $errorMessage = "Unknown error code."
    }

    # If the error message is the default message, attempt an online lookup.
    try {
        if ($errorMessage -eq "Unknown error code or not a Win32 error.") {
            $onlineErrorMessage = Get-OnlineErrorMessage -ErrorCode $ErrorCode
            if ($onlineErrorMessage) {
                $errorMessage = $onlineErrorMessage
            }
        }
    } catch { 
        Write-Debug "Failed to find online entry for code $ErrorCode. Error: $_"
        $errorMessage = "Unknown error code."
    }
    return $errorMessage
}

function Get-CustomErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ErrorCode
    )

    # Get error codes from configuration
    $errorDictionary = Get-AlertingConfig -Path "WindowsErrorCodes" -DefaultValue @{}
    
    # Convert error code to hex format for lookup
    $hexErrorCode = "0x{0:X8}" -f $ErrorCode
    
    return $errorDictionary.$hexErrorCode
}

function Get-OnlineErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ErrorCode
    )

    # Check cache first
    if ($global:OnlineErrorCache.ContainsKey($ErrorCode)) {
        Write-Debug "Returning cached online error for $ErrorCode"
        return $global:OnlineErrorCache[$ErrorCode]
    }

    # Convert error code to hexadecimal format
    $HexCode = "0x{0:X}" -f $ErrorCode
    Write-Debug "Looking up online error message for $HexCode"

    # Microsoft Learn URL (or any other trusted site for error codes)
    $url = "https://learn.microsoft.com/en-us/search/?terms=$HexCode"

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        # A simple regex to extract a paragraph from the page.
        $match = [regex]::Match($response.Content, "<p>(.*?)</p>")
        if ($match.Success) {
            $onlineMessage = $match.Groups[1].Value
        } else {
            $onlineMessage = "Online lookup failed or error code not found."
        }
    } catch {
        Write-Debug "Error during online lookup: $_"
        $onlineMessage = "Failed to connect to Microsoft or parse the response."
    }

    # Cache the result
    $global:OnlineErrorCache[$ErrorCode] = $onlineMessage
    return $onlineMessage
}

function Invoke-DiskUsageAlert {
    param (
        $Request,
        $HaloTicketCreate,
        $HaloClientDattoMatch
    )
    
    Write-Host "Alert detected for high disk usage on C: drive. Taking action..." 

    $AlertUID = $Request.Body.alertUID
    $AlertDetails = Get-DrmmAlert -alertUid $AlertUID
    $Device = Get-DrmmDevice -deviceUid $AlertDetails.alertSourceInfo.deviceUid
    $LastUser = $Device.lastLoggedInUser
    $Username = $LastUser -replace '^[^\\]*\\', ''

    Write-Host "Creating Ticket"
    $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate

    try {
        Send-HaloUserResponse -Username $Username `
            -ClientID $HaloClientDattoMatch `
            -TicketId $Ticket.id `
            -EmailMessage (Get-AlertingConfig -Path "CustomerNotifications.DiskUsage.EmailTemplate" -DefaultValue "<p>Your local storage is running low, with less than 10% remaining. To free up space, you might consider:<br><br>- Deleting unnecessary downloaded files<br>- Emptying the Recycle Bin<br>- Moving large files to cloud storage (e.g. OneDrive) and marking them as cloud-only.<br><br>If you're unable to resolve this issue or need further assistance, please reply to this email for support or call Aegis on 01865 393760.</p>") `
            -ErrorAction Stop
    }
    catch {
        Write-Host "Unable to find user '$Username'. Skipping sending Halo response."
    }
}

function Invoke-HyperVReplicationAlert {
    param ($HaloTicketCreate)

    Write-Host "Alert detected for Hyper-V Replication. Taking action..."

    $alertUID = ($HaloTicketCreate.customfields | Where-Object { $_.id -eq $DattoAlertUIDField }).value

    # Get business hours configuration
    $businessHours = Get-BusinessHoursConfig
    if (-not $businessHours) {
        Write-Warning "Business hours configuration not found. Using default behavior."
        $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
        return
    }

    $CurrentTimeUTC = [System.DateTime]::UtcNow
    try {
        $timeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($businessHours.TimeZone)
        $CurrentTimeLocal = [System.TimeZoneInfo]::ConvertTimeFromUtc($CurrentTimeUTC, $timeZone)
    } catch {
        Write-Warning "Invalid timezone '$($businessHours.TimeZone)'. Using UTC."
        $CurrentTimeLocal = $CurrentTimeUTC
    }

    # Check if today is a weekend (if configured to skip weekends)
    if ($businessHours.SkipWeekendsForHyperV -and ($CurrentTimeLocal.DayOfWeek.ToString() -notin $businessHours.WorkDays)) {
        Write-Output "Today is $($CurrentTimeLocal.DayOfWeek). No ticket will be created on weekends!"
        Set-DrmmAlertResolve -alertUid $alertUID
        return
    }

    # Check if within business hours
    try {
        $startTime = [datetime]::ParseExact($businessHours.StartTime, "HH:mm", $null)
        $endTime = [datetime]::ParseExact($businessHours.EndTime, "HH:mm", $null)
        $currentTime = $CurrentTimeLocal.TimeOfDay

        if ($currentTime -ge $startTime.TimeOfDay -and $currentTime -lt $endTime.TimeOfDay) {
            Write-Output "The current time is between $($businessHours.StartTime) and $($businessHours.EndTime) $($businessHours.TimeZone) time. A ticket will be created!"
            Write-Host "Creating Ticket"
            $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
        } else {
            Write-Output "The current time is outside of $($businessHours.StartTime) and $($businessHours.EndTime) $($businessHours.TimeZone) time. No ticket will be created!"
            Set-DrmmAlertResolve -alertUid $alertUID
        }
    } catch {
        Write-Warning "Error parsing business hours times. Creating ticket anyway."
        $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
    }
}

function Invoke-PatchMonitorAlert {
    param (
        $AlertWebhook,
        $HaloTicketCreate,
        $tableName
    )

    Write-Host "Alert detected for Patching. Taking action..."

    # Retrieve the alert details using the provided alert UID.
    $AlertID = $AlertWebhook.alertUID
    $AlertDRMM = Get-DrmmAlert -alertUid $AlertID

    if ($null -ne $AlertDRMM) {
        # Retrieve the device details and extract the hostname.
        $Device = Get-DrmmDevice -deviceUid $AlertDRMM.alertSourceInfo.deviceUid
        $DeviceHostname = $Device.hostname

        # Define partition and row keys for table storage.
        $partitionKey = Get-AlertingConfig -Path "Storage.PartitionKey" -DefaultValue "DeviceAlert"
        $rowKey = $DeviceHostname

        # Get the table reference.
        $table = Get-StorageTable -tableName $tableName
        
        # Use try-catch to handle potential race conditions in storage operations
        try {
            $entity = Get-StorageEntity -table $table -partitionKey $partitionKey -rowKey $rowKey

            if ($null -eq $entity) {
                # Create a new entity with an initial AlertCount of 1.
                # Use InsertOrMerge to handle race conditions where entity might be created by another process
                $entity = [Microsoft.Azure.Cosmos.Table.DynamicTableEntity]::new($partitionKey, $rowKey)
                $entity.Properties.Add("AlertCount", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForInt(1))
                $null = Add-StorageEntity -table $table -entity $entity
                
                # Re-fetch the entity to get current state after potential merge
                $entity = Get-StorageEntity -table $table -partitionKey $partitionKey -rowKey $rowKey
            } else {
                # Increment the alert count and update the entity.
                $entity.AlertCount++
                Update-AzTableRow -Table $table -entity $entity
            }

            # Check if the alert threshold is met or exceeded.
            $threshold = Get-AlertingConfig -Path "AlertThresholds.PatchAlertCount" -DefaultValue 2
            if ($entity.AlertCount -ge $threshold) {
                Write-Output "Alert count for $DeviceHostname has reached the threshold of $threshold."
                Write-Host "Creating Ticket"
                $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
                
                # Clean up the record from the table after handling the alert.
                try {
                    remove-AzTableRow -Table $table -PartitionKey $partitionKey -RowKey $rowKey
                } catch {
                    Write-Warning "Failed to clean up storage table row for $DeviceHostname`: $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Warning "Storage operation failed for device $DeviceHostname`: $($_.Exception.Message). Proceeding without storage tracking."
            # If storage fails, create ticket anyway to ensure alert is handled
            Write-Host "Creating Ticket (storage bypass)"
            $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
        }
    } else {
        Write-Host "Alert missing in Datto RMM, no further action..."
    }
}

function Invoke-BackupExecAlert {
    param ($HaloTicketCreate)

    Write-Host "Backup Exec Alert Detected"
    Write-Host "Creating Ticket"
    $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

function Invoke-HostsAlert {
    param ($HaloTicketCreate)

    Write-Host "Hosts Alert Detected"
    Write-Host "Creating Ticket"
    $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

function Find-ExistingSecurityAlert {
    <#
    .SYNOPSIS
    Searches for existing tickets that match the device and alert type pattern.
    
    .PARAMETER DeviceName
    The name of the device from the alert
    
    .PARAMETER AlertType
    The type of alert to search for (e.g., "An account failed to log on")
    
    .RETURNS
    Existing ticket object if found, null if not found
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [string]$AlertType
    )
    
    # Check if consolidation is enabled
    $consolidationEnabled = Get-AlertingConfig -Path "AlertConsolidation.EnableConsolidation" -DefaultValue $false
    if (-not $consolidationEnabled) {
        Write-Debug "Alert consolidation is disabled"
        return $null
    }
    
    # Check if this alert type should be consolidated
    $consolidatableTypesConfig = Get-AlertingConfig -Path "AlertConsolidation.ConsolidatableAlertTypes" -DefaultValue @()
    
    # Ensure we have a proper array for iteration
    $consolidatableTypes = @()
    if ($consolidatableTypesConfig) {
        if ($consolidatableTypesConfig -is [array]) {
            $consolidatableTypes = $consolidatableTypesConfig
        } elseif ($consolidatableTypesConfig -is [PSObject]) {
            # Convert PSObject to array if needed
            $consolidatableTypes = @($consolidatableTypesConfig.PSObject.Properties | ForEach-Object { $_.Value })
        } else {
            # Single item, make it an array
            $consolidatableTypes = @($consolidatableTypesConfig)
        }
    }
    
    $shouldConsolidate = $false
    foreach ($type in $consolidatableTypes) {
        if ($AlertType -like "*$type*") {
            $shouldConsolidate = $true
            break
        }
    }
    
    if (-not $shouldConsolidate) {
        Write-Debug "Alert type '$AlertType' is not configured for consolidation"
        return $null
    }
    
    try {
        # Get configuration for search
        $windowHours = Get-AlertingConfig -Path "AlertConsolidation.ConsolidationWindowHours" -DefaultValue 24
        
        Write-Host "Consolidation window: $windowHours hours"
        
        # Build search query - looking for tickets with similar subject pattern
        # The actual format is: "Device: hostname raised Alert: AlertType - AlertMessage"
        # We need to search more broadly to catch different alert type prefixes
        $searchPattern = "Device: $DeviceName raised Alert:*$AlertType*"
        
        Write-Host "Searching for existing tickets matching pattern: $searchPattern"
        
        # Search for tickets using Halo API with -SearchSummary and -OpenOnly (so all results are already open)
        # Using -SearchSummary instead of -Search to work around API bug with device names ending in numbers
        $searchResults = Get-HaloTicket -SearchSummary "Device: $DeviceName" -OpenOnly -FullObjects
        
        Write-Host "Search returned $($searchResults.Count) open tickets for device: $DeviceName"
        
        if ($searchResults -and $searchResults.Count -gt 0) {
            # Filter results by alert type - no need to check status since -OpenOnly guarantees open tickets
            # No need to check date since open tickets are still relevant for consolidation
            $matchingTickets = @()
            
            foreach ($ticket in $searchResults) {
                # Check if ticket summary contains our alert type
                if ($ticket.summary -like "*$AlertType*") {
                    Write-Host "Found potential consolidation ticket: ID $($ticket.id) - $($ticket.summary)"
                    $matchingTickets += $ticket
                } else {
                    Write-Host "Ticket $($ticket.id) does not contain alert type '$AlertType' in summary: $($ticket.summary)"
                }
            }
            
            # If we found multiple matching tickets, select the best one
            if ($matchingTickets.Count -gt 1) {
                Write-Host "Found $($matchingTickets.Count) matching tickets. Selecting the most recent one."
                
                # Sort by ticket ID (assuming higher ID = more recent) and take the most recent
                $selectedTicket = $matchingTickets | Sort-Object { [int]$_.id } -Descending | Select-Object -First 1
                Write-Host "Selected ticket ID $($selectedTicket.id) as the most recent for consolidation"
                return $selectedTicket
            } elseif ($matchingTickets.Count -eq 1) {
                # Safe indexing for single item
                $singleTicket = if ($matchingTickets -is [array]) { $matchingTickets[0] } else { $matchingTickets }
                Write-Host "Found single matching ticket for consolidation: ID $($singleTicket.id)"
                return $singleTicket
            }
        }
        
        Write-Host "No existing tickets found for consolidation"
        return $null
    }
    catch {
        Write-Warning "Error searching for existing tickets: $($_.Exception.Message)"
        return $null
    }
}

function Update-ExistingSecurityTicket {
    <#
    .SYNOPSIS
    Updates an existing ticket with information about a new occurrence of the same alert.
    
    .PARAMETER ExistingTicket
    The existing ticket to update
    
    .PARAMETER AlertType
    The type of alert that occurred
    
    .PARAMETER NewAlertDetails
    Details of the new alert occurrence
    
    .RETURNS
    True if update successful, false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$ExistingTicket,
        [Parameter(Mandatory)]
        [string]$AlertType,
        [Parameter(Mandatory)]
        [PSObject]$NewAlertDetails
    )
    
    try {
        # Get consolidation configuration
        $maxCount = Get-AlertingConfig -Path "AlertConsolidation.MaxConsolidationCount" -DefaultValue 50
        $noteTemplate = Get-AlertingConfig -Path "AlertConsolidation.ConsolidationNoteTemplate" -DefaultValue "Additional {AlertType} alert detected at {Timestamp}. Total occurrences: {Count}"
        
        # Check if we've reached max consolidation limit
        # Get ticket actions separately using Get-HaloAction
        $ticketActions = @()
        try {
            $ticketActions = Get-HaloAction -TicketID $ExistingTicket.id -Count 10000
        } catch {
            Write-Warning "Failed to get actions for ticket $($ExistingTicket.id): $($_.Exception.Message)"
        }
        
        # Find consolidation notes
        $consolidationNotes = @()
        if ($ticketActions) {
            $consolidationNotes = $ticketActions | Where-Object { $_.note -like "*Additional $AlertType alert detected*" }
        }
        $currentCount = $consolidationNotes.Count + 1 # +1 for the original ticket
        
        if ($currentCount -ge $maxCount) {
            Write-Warning "Maximum consolidation count ($maxCount) reached for ticket $($ExistingTicket.id). Creating new ticket instead."
            return $false
        }
        
        # Check if we should send a Teams notification for high consolidation count
        $teamsNotificationThreshold = Get-AlertingConfig -Path "AlertConsolidation.TeamsNotificationThreshold" -DefaultValue 3
        if (($currentCount + 1) -ge $teamsNotificationThreshold) {
            # Extract device name from ticket summary for Teams notification
            $deviceName = "Unknown Device"
            if ($ExistingTicket.summary -match "Device:\s*([^\s]+)\s+raised Alert") {
                $deviceName = $matches[1]
            }
            
            Send-AlertConsolidationTeamsNotification -DeviceName $deviceName -AlertType $AlertType -AlertDetails $AlertType -OccurrenceCount ($currentCount + 1) -TicketId $ExistingTicket.id -AlertWebhook $NewAlertDetails
        }
        
        # Create consolidation note
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $consolidationNote = $noteTemplate -replace "\{AlertType\}", $AlertType -replace "\{Timestamp\}", $timestamp -replace "\{Count\}", ($currentCount + 1)
        
        # Add details from the new alert
        $consolidationNote += "`n`nNew Alert Details:`n"
        if ($NewAlertDetails.alertMessage) {
            $consolidationNote += "Alert Message: $($NewAlertDetails.alertMessage)`n"
        }
        if ($NewAlertDetails.alertUID) {
            $consolidationNote += "Alert UID: $($NewAlertDetails.alertUID)`n"
        }
        
        # Create the action object for adding a note
        $actionToAdd = @{
            ticket_id = $ExistingTicket.id
            actionid          = 23
            outcome           = "Remote"
            outcome_id        = 23
            note = $consolidationNote
            actionarrivaldate = Get-Date
            actioncompletiondate = Get-Date
            action_isresponse = $false
            validate_response = $false
            sendemail = $false
        }
        
        # Add the note to the ticket
        $actionResult = New-HaloAction -Action $actionToAdd
        
        if ($actionResult) {
            Write-Host "Successfully updated ticket $($ExistingTicket.id) with new alert details."
            return $true
        } else {
            Write-Warning "Failed to update ticket $($ExistingTicket.id)."
            return $false
        }
    }
    catch {
        Write-Error "Error updating existing ticket: $($_.Exception.Message)"
        return $false
    }
}

function Test-AlertConsolidation {
    <#
    .SYNOPSIS
    Tests if an alert should be consolidated with an existing ticket.
    
    .PARAMETER HaloTicketCreate
    The ticket object that would be created
    
    .PARAMETER AlertWebhook
    The webhook data from the alert
    
    .RETURNS
    True if alert was consolidated, false if new ticket should be created
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$HaloTicketCreate,
        [Parameter(Mandatory)]
        [PSObject]$AlertWebhook
    )
    
    try {
        # Extract device name from ticket summary
        if ($HaloTicketCreate.summary -match "Device:\s*([^\s]+)\s+raised Alert") {
            $deviceName = $matches[1]
        } else {
            Write-Host "Could not extract device name from ticket summary: $($HaloTicketCreate.summary)"
            return $false
        }
        
        # Extract alert type from the summary
        # Format is: "Device: hostname raised Alert: AlertCategory - AlertMessage"
        # We want to extract the AlertMessage part for matching
        $alertType = ""
        if ($HaloTicketCreate.summary -match "raised Alert:\s*([^-]+)\s*-\s*(.+?)(\s+Subject:|$)") {
            # Extract the message part after the dash
            $alertType = $matches[2].Trim().TrimEnd('.')
        } elseif ($HaloTicketCreate.summary -match "raised Alert:\s*(.+?)(\s+Subject:|$)") {
            # Fallback to extract everything after "raised Alert:"
            $alertType = $matches[1].Trim().TrimEnd('.')
        } else {
            Write-Host "Could not extract alert type from ticket summary: $($HaloTicketCreate.summary)"
            return $false
        }
        
        Write-Host "Full ticket summary: $($HaloTicketCreate.summary)"
        Write-Host "Testing consolidation for device '$deviceName' and alert type '$alertType'"
        
        # Search for existing ticket
        $existingTicket = Find-ExistingSecurityAlert -DeviceName $deviceName -AlertType $alertType
        
        if ($existingTicket) {
            Write-Host "Found existing ticket for consolidation: $($existingTicket.id)"
            
            # Update the existing ticket
            $updateResult = Update-ExistingSecurityTicket -ExistingTicket $existingTicket -AlertType $alertType -NewAlertDetails $AlertWebhook
            
            if ($updateResult) {
                Write-Host "Successfully consolidated alert into existing ticket $($existingTicket.id)"
                return $true
            } else {
                Write-Warning "Failed to consolidate alert. Will create new ticket."
                return $false
            }
        } else {
            Write-Host "No existing ticket found for consolidation. Will create new ticket."
            return $false
        }
    }
    catch {
        Write-Error "Error in alert consolidation test: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-DefaultAlert {
    param ($HaloTicketCreate)

    Write-Host "Creating Ticket without additional processing!"
    $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

function Find-ExistingMemoryUsageAlert {
    <#
    .SYNOPSIS
    Searches for existing memory usage tickets for the same device to enable consolidation.
    
    .PARAMETER DeviceName
    The name of the device from the alert
    
    .PARAMETER MemoryPercentage
    The memory usage percentage from the alert
    
    .RETURNS
    Existing ticket object if found, null if not found
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [int]$MemoryPercentage
    )
    
    # Check if consolidation is enabled
    $consolidationEnabled = Get-AlertingConfig -Path "AlertConsolidation.EnableConsolidation" -DefaultValue $false
    if (-not $consolidationEnabled) {
        Write-Debug "Alert consolidation is disabled"
        return $null
    }
    
    # Check if memory usage alerts should be consolidated
    $consolidatableTypesConfig = Get-AlertingConfig -Path "AlertConsolidation.ConsolidatableAlertTypes" -DefaultValue @()
    
    # Ensure we have a proper array for iteration
    $consolidatableTypes = @()
    if ($consolidatableTypesConfig) {
        if ($consolidatableTypesConfig -is [array]) {
            $consolidatableTypes = $consolidatableTypesConfig
        } elseif ($consolidatableTypesConfig -is [PSObject]) {
            # Convert PSObject to array if needed
            $consolidatableTypes = @($consolidatableTypesConfig.PSObject.Properties | ForEach-Object { $_.Value })
        } else {
            # Single item, make it an array
            $consolidatableTypes = @($consolidatableTypesConfig)
        }
    }
    
    $shouldConsolidate = $false
    foreach ($type in $consolidatableTypes) {
        if ("Memory Usage" -like "*$type*" -or $type -like "*Memory*" -or $type -like "*memory*") {
            $shouldConsolidate = $true
            break
        }
    }
    
    if (-not $shouldConsolidate) {
        Write-Debug "Memory Usage alerts are not configured for consolidation"
        return $null
    }
    
    try {
        Write-Host "Searching for existing memory usage tickets for device: $DeviceName"
        
        # Search for tickets with memory usage pattern for this device
        $searchResults = Get-HaloTicket -SearchSummary "Device: $DeviceName" -OpenOnly -FullObjects
        
        Write-Host "Search returned $($searchResults.Count) open tickets for device: $DeviceName"
        
        if ($searchResults -and $searchResults.Count -gt 0) {
            $matchingTickets = @()
            
            foreach ($ticket in $searchResults) {
                # Check if ticket summary contains memory usage pattern
                # Looking for: "Device: GUILWKS0062 raised Alert: - Memory Usage reached XX%"
                if ($ticket.summary -match "Device:\s*$([regex]::Escape($DeviceName))\s+raised Alert:\s*-?\s*Memory Usage reached \d+%") {
                    Write-Host "Found potential memory usage consolidation ticket: ID $($ticket.id) - $($ticket.summary)"
                    $matchingTickets += $ticket
                }
            }
            
            if ($matchingTickets.Count -gt 0) {
                # Return the most recent ticket for consolidation
                return $matchingTickets | Sort-Object date_created -Descending | Select-Object -First 1
            }
        }
        
        Write-Host "No existing memory usage tickets found for device: $DeviceName"
        return $null
    }
    catch {
        Write-Error "Error searching for existing memory usage alerts: $($_.Exception.Message)"
        return $null
    }
}

function Test-MemoryUsageConsolidation {
    <#
    .SYNOPSIS
    Tests if a memory usage alert should be consolidated with an existing ticket.
    
    .PARAMETER HaloTicketCreate
    The ticket object that would be created
    
    .PARAMETER AlertWebhook
    The webhook data from the alert
    
    .RETURNS
    True if alert was consolidated, false if new ticket should be created
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$HaloTicketCreate,
        [Parameter(Mandatory)]
        [PSObject]$AlertWebhook
    )
    
    try {
        # Check if this is a memory usage alert
        # Expected format: "Device: GUILWKS0062 raised Alert: - Memory Usage reached 99%"
        if ($HaloTicketCreate.summary -notmatch "Memory Usage reached (\d+)%") {
            Write-Debug "Not a memory usage alert, skipping memory usage consolidation"
            return $false
        }
        
        # Extract device name and memory percentage
        $deviceName = ""
        $memoryPercentage = 0
        
        if ($HaloTicketCreate.summary -match "Device:\s*([^\s]+)\s+raised Alert") {
            $deviceName = $matches[1]
        } else {
            Write-Host "Could not extract device name from memory usage alert: $($HaloTicketCreate.summary)"
            return $false
        }
        
        if ($HaloTicketCreate.summary -match "Memory Usage reached (\d+)%") {
            $memoryPercentage = [int]$matches[1]
        } else {
            Write-Host "Could not extract memory percentage from alert: $($HaloTicketCreate.summary)"
            return $false
        }
        
        Write-Host "Testing memory usage consolidation for device '$deviceName' at $memoryPercentage% usage"
        
        # Search for existing memory usage ticket
        $existingTicket = Find-ExistingMemoryUsageAlert -DeviceName $deviceName -MemoryPercentage $memoryPercentage
        
        if ($existingTicket) {
            Write-Host "Found existing memory usage ticket for consolidation: $($existingTicket.id)"
            
            # Update the existing ticket with new memory usage data
            $updateResult = Update-ExistingMemoryUsageTicket -ExistingTicket $existingTicket -DeviceName $deviceName -MemoryPercentage $memoryPercentage -AlertWebhook $AlertWebhook
            
            if ($updateResult) {
                Write-Host "Successfully consolidated memory usage alert into existing ticket $($existingTicket.id)"
                return $true
            } else {
                Write-Warning "Failed to consolidate memory usage alert. Will create new ticket."
                return $false
            }
        } else {
            Write-Host "No existing memory usage ticket found for consolidation. Will create new ticket."
            return $false
        }
    }
    catch {
        Write-Error "Error in memory usage consolidation test: $($_.Exception.Message)"
        return $false
    }
}

function Update-ExistingMemoryUsageTicket {
    <#
    .SYNOPSIS
    Updates an existing memory usage ticket with new memory usage data.
    
    .PARAMETER ExistingTicket
    The existing ticket to update
    
    .PARAMETER DeviceName
    The device name from the alert
    
    .PARAMETER MemoryPercentage
    The current memory usage percentage
    
    .PARAMETER AlertWebhook
    The webhook data from the alert
    
    .RETURNS
    True if update successful, false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$ExistingTicket,
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [int]$MemoryPercentage,
        [Parameter(Mandatory)]
        [PSObject]$AlertWebhook
    )
    
    try {
        # Get configuration for consolidation
        $maxCount = Get-AlertingConfig -Path "AlertConsolidation.MaxConsolidationCount" -DefaultValue 50
        $noteTemplate = Get-AlertingConfig -Path "AlertConsolidation.MemoryUsageNoteTemplate" -DefaultValue "Additional Memory Usage alert: Device {DeviceName} reached {MemoryPercentage}% at {Timestamp}. Current occurrence count: {Count}"
        
        # Count existing occurrences in the ticket actions/notes
        $occurrenceCount = 1
        try {
            $ticketActions = Get-HaloAction -TicketID $ExistingTicket.id -Count 10000
            if ($ticketActions) {
                $memoryUsageNotes = $ticketActions | Where-Object { $_.note -like "*Memory Usage alert*" -or $_.note -like "*memory usage*" }
                $occurrenceCount = $memoryUsageNotes.Count + 1
            }
        } catch {
            Write-Warning "Failed to get actions for memory consolidation ticket $($ExistingTicket.id): $($_.Exception.Message)"
        }
        
        # Check if we've hit the max consolidation limit
        if ($occurrenceCount -gt $maxCount) {
            Write-Warning "Memory usage consolidation limit ($maxCount) reached for ticket $($ExistingTicket.id). Creating new ticket."
            return $false
        }
        
        # Check if we should send a Teams notification for high consolidation count
        $teamsNotificationThreshold = Get-AlertingConfig -Path "AlertConsolidation.TeamsNotificationThreshold" -DefaultValue 3
        if ($occurrenceCount -ge $teamsNotificationThreshold) {
            Send-MemoryUsageTeamsNotification -DeviceName $DeviceName -MemoryPercentage $MemoryPercentage -OccurrenceCount $occurrenceCount -TicketId $ExistingTicket.id -AlertWebhook $AlertWebhook
        }
        
        # Update the ticket summary to reflect latest memory usage
        $updatedSummary = "Device: $DeviceName raised Alert: - Memory Usage reached $MemoryPercentage% (Alert #$occurrenceCount)"
        
        # Create the consolidation note
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $consolidationNote = $noteTemplate -replace "{DeviceName}", $DeviceName `
                                          -replace "{MemoryPercentage}", $MemoryPercentage `
                                          -replace "{Timestamp}", $timestamp `
                                          -replace "{Count}", $occurrenceCount
        
        # Prepare ticket update
        $ticketUpdate = @{
            id = $ExistingTicket.id
            summary = $updatedSummary
        }
        
        Write-Host "Updating memory usage ticket $($ExistingTicket.id) with: $consolidationNote"
        
        # Update the ticket
        $updateResult = Set-HaloTicket -Ticket $ticketUpdate
        
        if ($updateResult) {
            # Add the consolidation note
            $action = @{
                ticket_id = $ExistingTicket.id
                note = $consolidationNote
                note_html = "<p><strong>Memory Usage Alert Consolidation:</strong><br>$consolidationNote</p>"
                actiontypeid = 1  # Note action type
                sendemail = $false
            }
            
            $actionResult = New-HaloAction -Action $action
            
            if ($actionResult) {
                Write-Host "Successfully updated memory usage ticket $($ExistingTicket.id) with consolidation data"
                return $true
            } else {
                Write-Warning "Updated ticket but failed to add consolidation note"
                return $true  # Still consider it successful since ticket was updated
            }
        } else {
            Write-Error "Failed to update memory usage ticket $($ExistingTicket.id)"
            return $false
        }
    }
    catch {
        Write-Error "Error updating existing memory usage ticket: $($_.Exception.Message)"
        return $false
    }
}

function Get-TeamsWebhookConfig {
    <#
    .SYNOPSIS
    Loads the Teams webhook configuration from teams-webhook-config.json
    
    .RETURNS
    Teams webhook configuration object or null if not found
    #>
    try {
        $configPath = Join-Path $PSScriptRoot "..\teams-webhook-config.json"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath | ConvertFrom-Json
            return $config
        } else {
            Write-Warning "Teams webhook config file not found at: $configPath"
            return $null
        }
    }
    catch {
        Write-Warning "Failed to load Teams webhook configuration: $($_.Exception.Message)"
        return $null
    }
}

function Send-AlertConsolidationTeamsNotification {
    <#
    .SYNOPSIS
    Sends a Microsoft Teams notification when alerts are consolidated multiple times.
    
    .PARAMETER DeviceName
    The device name experiencing the issue
    
    .PARAMETER AlertType
    The type of alert (e.g., "Security", "Memory Usage", "Disk Usage")
    
    .PARAMETER AlertDetails
    Additional details about the alert (e.g., memory percentage, security event)
    
    .PARAMETER OccurrenceCount
    The number of times this alert has been consolidated
    
    .PARAMETER TicketId
    The HaloPSA ticket ID
    
    .PARAMETER AlertWebhook
    The original alert webhook data
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [string]$AlertType,
        [Parameter(Mandatory)]
        [string]$AlertDetails,
        [Parameter(Mandatory)]
        [int]$OccurrenceCount,
        [Parameter(Mandatory)]
        [int]$TicketId,
        [Parameter(Mandatory)]
        [PSObject]$AlertWebhook
    )
    
    try {
        # Check if we've already sent a Teams notification today for this device/alert type
        if (Test-DailyTeamsNotificationSent -DeviceName $DeviceName -AlertType $AlertType) {
            Write-Host "Skipping Teams notification - already sent today for $DeviceName ($AlertType)"
            return
        }
        
        # Get Teams webhook configuration
        $teamsConfig = Get-TeamsWebhookConfig
        if (-not $teamsConfig -or -not $teamsConfig.TeamsNotifications.EnableNotifications) {
            Write-Host "Teams notifications are disabled. Skipping notification."
            return
        }
        
        $teamsWebhookUrl = $teamsConfig.TeamsNotifications.WebhookUrl
        if (-not $teamsWebhookUrl) {
            Write-Warning "Teams webhook URL not configured. Skipping Teams notification."
            return
        }
        
        # Determine severity and color based on alert type and occurrence count
        $severity = "Medium"
        $color = "warning" # Orange
        $icon = "[WARN]"
        
        # Set severity based on alert type and occurrence count
        switch ($AlertType.ToLower()) {
            "security" {
                $icon = "[LOCK]"
                if ($OccurrenceCount -ge 5) {
                    $severity = "Critical"
                    $color = "attention" # Red
                } elseif ($OccurrenceCount -ge 3) {
                    $severity = "High"
                    $color = "attention"
                } else {
                    $severity = "Medium"
                    $color = "warning"
                }
            }
            "memory usage" {
                $icon = "[MEM]"
                # Check if memory percentage is in alert details
                if ($AlertDetails -match "(\d+)%") {
                    $memoryPercentage = [int]$matches[1]
                    if ($memoryPercentage -ge 95 -or $OccurrenceCount -ge 5) {
                        $severity = "Critical"
                        $color = "attention"
                    } elseif ($memoryPercentage -ge 85 -and $OccurrenceCount -ge 3) {
                        $severity = "High"
                        $color = "attention"
                    }
                }
            }
            "disk usage" {
                $icon = "[DISK]"
                if ($OccurrenceCount -ge 5) {
                    $severity = "High"
                    $color = "attention"
                } elseif ($OccurrenceCount -ge 3) {
                    $severity = "Medium"
                    $color = "warning"
                }
            }
            "event log" {
                $icon = "[LOG]"
                if ($OccurrenceCount -ge 10) {
                    $severity = "High"
                    $color = "attention"
                } elseif ($OccurrenceCount -ge 5) {
                    $severity = "Medium"
                    $color = "warning"
                }
            }
            default {
                $icon = "[ALERT]"
                if ($OccurrenceCount -ge 5) {
                    $severity = "High"
                    $color = "attention"
                } elseif ($OccurrenceCount -ge 3) {
                    $severity = "Medium"
                    $color = "warning"
                }
            }
        }
        
        # Get additional context
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
        $clientInfo = "Unknown Client"
        $siteInfo = "Unknown Site"
        
        # Try to extract client/site info from webhook data
        if ($AlertWebhook.dattoSiteDetails) {
            $siteDetails = $AlertWebhook.dattoSiteDetails
            if ($siteDetails -match "(.+)\((.+)\)") {
                $siteInfo = $matches[1].Trim()
                $clientInfo = $matches[2].Trim()
            } else {
                $siteInfo = $siteDetails
            }
        }
        
        # Create the Teams message payload using Adaptive Cards
        $teamsPayload = @{
            type = "message"
            attachments = @(
                @{
                    contentType = "application/vnd.microsoft.card.adaptive"
                    content = @{
                        type = "AdaptiveCard"
                        version = "1.4"
                        body = @(
                            @{
                                type = "Container"
                                style = $color
                                items = @(
                                    @{
                                        type = "TextBlock"
                                        text = "$icon Alert Consolidation: $AlertType"
                                        weight = "Bolder"
                                        size = "Large"
                                        color = "Light"
                                    }
                                )
                            },
                            @{
                                type = "FactSet"
                                facts = @(
                                    @{
                                        title = "Device"
                                        value = $DeviceName
                                    },
                                    @{
                                        title = "Client"
                                        value = $clientInfo
                                    },
                                    @{
                                        title = "Site"
                                        value = $siteInfo
                                    },
                                    @{
                                        title = "Alert Type"
                                        value = $AlertType
                                    },
                                    @{
                                        title = "Alert Details"
                                        value = $AlertDetails
                                    },
                                    @{
                                        title = "Alert Count"
                                        value = "$OccurrenceCount alerts consolidated"
                                    },
                                    @{
                                        title = "Severity"
                                        value = $severity
                                    },
                                    @{
                                        title = "Ticket ID"
                                        value = "#$TicketId"
                                    },
                                    @{
                                        title = "Timestamp"
                                        value = $timestamp
                                    }
                                )
                            },
                            @{
                                type = "TextBlock"
                                text = "Multiple **$AlertType** alerts have been consolidated for device **$DeviceName**. This may indicate a persistent issue requiring attention."
                                wrap = $true
                                spacing = "Medium"
                            }
                        )
                        actions = @(
                            @{
                                type = "Action.OpenUrl"
                                title = "View Ticket in HaloPSA"
                                url = "https://support.aegis-group.co.uk/tickets?id=$TicketId"
                            }
                        )
                    }
                }
            )
        }
        
        # Convert to JSON
        $jsonPayload = $teamsPayload | ConvertTo-Json -Depth 10 -Compress
        
        Write-Host "Sending Teams notification for $AlertType consolidation on device $DeviceName (Alert #$OccurrenceCount)"
        
        # Send the webhook
        $null = Invoke-RestMethod -Uri $teamsWebhookUrl -Method POST -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
        
        Write-Host "Teams notification sent successfully for $AlertType consolidation"
        
        # Record that we've sent a notification today for this device/alert type
        Record-DailyTeamsNotificationSent -DeviceName $DeviceName -AlertType $AlertType -TicketId $TicketId
        
        # Log the notification for monitoring
        $logEntry = @{
            Timestamp = $timestamp
            Device = $DeviceName
            Client = $clientInfo
            Site = $siteInfo
            AlertType = $AlertType
            AlertDetails = $AlertDetails
            OccurrenceCount = $OccurrenceCount
            TicketId = $TicketId
            Severity = $severity
            NotificationSent = $true
        }
        
        Write-Host "TEAMS_NOTIFICATION_LOG: $($logEntry | ConvertTo-Json -Compress)"
        
    }

    catch {
        Write-Error "Failed to send Teams notification for $AlertType consolidation: $($_.Exception.Message)"
        Write-Host "Teams webhook URL: $teamsWebhookUrl"
        Write-Host "Error details: $($_.Exception.ToString())"
        
        # Log the failure
        $errorLogEntry = @{
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
            Device = $DeviceName
            AlertType = $AlertType
            OccurrenceCount = $OccurrenceCount
            TicketId = $TicketId
            NotificationSent = $false
            Error = $_.Exception.Message
        }
        
        Write-Host "TEAMS_NOTIFICATION_ERROR: $($errorLogEntry | ConvertTo-Json -Compress)"
    }
}

function Test-DailyTeamsNotificationSent {
    <#
    .SYNOPSIS
    Checks if a Teams notification has already been sent today for a specific device and alert type.
    
    .PARAMETER DeviceName
    The device name
    
    .PARAMETER AlertType
    The type of alert (e.g., "Memory Usage", "Security")
    
    .RETURNS
    True if notification was already sent today, False otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [string]$AlertType
    )
    
    try {
        # Check if we have storage access
        if (-not $table) {
            Write-Host "Azure Table storage not available, allowing notification"
            return $false
        }
        
        # Create unique identifier for this device/alert combination
        $today = Get-Date -Format "yyyy-MM-dd"
        $partitionKey = "TeamsNotifications"
        $rowKey = "$DeviceName-$AlertType-$today"
        
        # Query for existing record
        $existingRecord = Get-AzTableRow -Table $table -PartitionKey $partitionKey -RowKey $rowKey -ErrorAction SilentlyContinue
        
        if ($existingRecord) {
            Write-Host "Teams notification already sent today for $DeviceName ($AlertType)"
            return $true
        } else {
            Write-Host "No Teams notification sent today for $DeviceName ($AlertType)"
            return $false
        }
    } catch {
        Write-Warning "Failed to check Teams notification history: $($_.Exception.Message)"
        # On error, allow the notification to be sent
        return $false
    }
}

function Record-DailyTeamsNotificationSent {
    <#
    .SYNOPSIS
    Records that a Teams notification has been sent for a specific device and alert type today.
    
    .PARAMETER DeviceName
    The device name
    
    .PARAMETER AlertType
    The type of alert (e.g., "Memory Usage", "Security")
    
    .PARAMETER TicketId
    The associated ticket ID
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [string]$AlertType,
        [Parameter(Mandatory)]
        [int]$TicketId
    )
    
    try {
        # Check if we have storage access
        if (-not $table) {
            Write-Host "Azure Table storage not available, skipping notification record"
            return
        }
        
        # Create unique identifier for this device/alert combination
        $today = Get-Date -Format "yyyy-MM-dd"
        $timestamp = Get-Date
        $partitionKey = "TeamsNotifications"
        $rowKey = "$DeviceName-$AlertType-$today"
        
        # Create record
        $record = @{
            PartitionKey = $partitionKey
            RowKey = $rowKey
            DeviceName = $DeviceName
            AlertType = $AlertType
            TicketId = $TicketId
            NotificationDate = $today
            Timestamp = $timestamp
        }
        
        # Store the record
        $null = Add-AzTableRow -Table $table -PartitionKey $partitionKey -RowKey $rowKey -Property $record -ErrorAction Stop
        Write-Host "Recorded Teams notification for $DeviceName ($AlertType) - Ticket #$TicketId"
        
    } catch {
        Write-Warning "Failed to record Teams notification: $($_.Exception.Message)"
        # Don't throw error - notification was already sent successfully
    }
}

function Send-MemoryUsageTeamsNotification {
    <#
    .SYNOPSIS
    Legacy wrapper for memory usage Teams notifications. Calls the generic notification function.
    
    .PARAMETER DeviceName
    The device name experiencing memory issues
    
    .PARAMETER MemoryPercentage
    The current memory usage percentage
    
    .PARAMETER OccurrenceCount
    The number of times this alert has been consolidated
    
    .PARAMETER TicketId
    The HaloPSA ticket ID
    
    .PARAMETER AlertWebhook
    The original alert webhook data
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [int]$MemoryPercentage,
        [Parameter(Mandatory)]
        [int]$OccurrenceCount,
        [Parameter(Mandatory)]
        [int]$TicketId,
        [Parameter(Mandatory)]
        [PSObject]$AlertWebhook
    )
    
    # Call the generic function with memory-specific parameters
    Send-AlertConsolidationTeamsNotification -DeviceName $DeviceName -AlertType "Memory Usage" -AlertDetails "$MemoryPercentage% memory usage" -OccurrenceCount $OccurrenceCount -TicketId $TicketId -AlertWebhook $AlertWebhook
    <#
    .SYNOPSIS
    Sends a Microsoft Teams notification when memory usage alerts are consolidated multiple times.
    
    .PARAMETER DeviceName
    The device name experiencing memory issues
    
    .PARAMETER MemoryPercentage
    The current memory usage percentage
    
    .PARAMETER OccurrenceCount
    The number of times this alert has been consolidated
    
    .PARAMETER TicketId
    The HaloPSA ticket ID
    
    .PARAMETER AlertWebhook
    The original alert webhook data
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceName,
        [Parameter(Mandatory)]
        [int]$MemoryPercentage,
        [Parameter(Mandatory)]
        [int]$OccurrenceCount,
        [Parameter(Mandatory)]
        [int]$TicketId,
        [Parameter(Mandatory)]
        [PSObject]$AlertWebhook
    )
    
    # Call the generic function with memory-specific parameters
    Send-AlertConsolidationTeamsNotification -DeviceName $DeviceName -AlertType "Memory Usage" -AlertDetails "$MemoryPercentage% memory usage" -OccurrenceCount $OccurrenceCount -TicketId $TicketId -AlertWebhook $AlertWebhook
}

# Export the public functions
Export-ModuleMember -Function @(
    'New-HaloTicketWithFallback',
    'New-MinimalTicketContent',
    'Get-WindowsErrorMessage',
    'Get-CustomErrorMessage',
    'Get-OnlineErrorMessage',
    'Invoke-DiskUsageAlert',
    'Invoke-HyperVReplicationAlert',
    'Invoke-PatchMonitorAlert',
    'Invoke-BackupExecAlert',
    'Invoke-HostsAlert',
    'Invoke-DefaultAlert',
    'Find-ExistingSecurityAlert',
    'Update-ExistingSecurityTicket',
    'Test-AlertConsolidation',
    'Find-ExistingMemoryUsageAlert',
    'Test-MemoryUsageConsolidation',
    'Update-ExistingMemoryUsageTicket',
    'Get-TeamsWebhookConfig',
    'Send-AlertConsolidationTeamsNotification',
    'Send-MemoryUsageTeamsNotification',
    'Test-DailyTeamsNotificationSent',
    'Record-DailyTeamsNotificationSent'
)
