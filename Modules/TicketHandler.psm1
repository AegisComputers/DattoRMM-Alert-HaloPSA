# TicketHandler.ps1
# Set environment variables and local variables
$storageAccountName = Get-AlertingConfig -Path "Storage.StorageAccountName" -DefaultValue "dattohaloalertsstgnirab"
$storageAccountKey = $env:strKey
$tableName = Get-AlertingConfig -Path "Storage.TableName" -DefaultValue "DevicePatchAlerts"

# Ensure the storage account key is set
if (-not $storageAccountKey) {
    Write-Error "Storage account key is not set. Please set the environment variable 'strKey'."
    exit 1
}

#Halo Vars
$HaloClientID = $env:HaloClientID
$HaloClientSecret = $env:HaloClientSecret
$HaloURL = $env:HaloURL
$HaloTicketStatusID = $env:HaloTicketStatusID
$HaloCustomAlertTypeField = $env:HaloCustomAlertTypeField
$HaloTicketType = $env:HaloTicketType
$HaloReocurringStatus = $env:HaloReocurringStatus

#Datto Vars
$DattoURL = $env:DattoURL
$DattoKey = $env:DattoKey
$DattoSecretKey = $env:DattoSecretKey
$DattoAlertUIDField = $env:DattoAlertUIDField

# Connect to Azure Storage
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$table = Get-StorageTable -Context $context -TableName $tableName

## Global cache for online error lookups
$global:OnlineErrorCache = @{}

function New-HaloTicketWithFallback {
    param ($HaloTicketCreate)

    try {
        $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
        Write-Host "Ticket created successfully with ID: $($Ticket.id)"
        return $Ticket
    }
    catch {
        Write-Error "Failed to create Halo ticket: $($_.Exception.Message)"
        
        # If it's a timeout error, try with minimal details
        if ($_.Exception.Message -like "*504*" -or $_.Exception.Message -like "*timeout*" -or $_.Exception.Message -like "*Gateway Time-out*") {
            Write-Host "Attempting to create ticket with minimal details due to timeout..."
            $HaloTicketCreateFallback = $HaloTicketCreate.Clone()
            
            # Create a very basic ticket with essential information only
            $AlertUID = ($HaloTicketCreate.customfields | Where-Object { $_.id -eq $env:DattoAlertUIDField }).value
            $TicketSummary = $HaloTicketCreate.summary
            
            # Use helper function to create minimal content
            $MinimalContent = New-MinimalTicketContent -TicketSummary $TicketSummary -AlertUID $AlertUID
            $HaloTicketCreateFallback.details_html = $MinimalContent
            
            try {
                $Ticket = New-HaloTicket -Ticket $HaloTicketCreateFallback
                Write-Host "Fallback ticket created successfully with ID: $($Ticket.id)"
                return $Ticket
            }
            catch {
                Write-Error "Failed to create fallback ticket: $($_.Exception.Message)"
                throw
            }
        }
        else {
            throw
        }
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

function Handle-DiskUsageAlert {
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
        FindAndSendHaloResponse -Username $Username `
            -ClientID $HaloClientDattoMatch `
            -TicketId $Ticket.id `
            -EmailMessage (Get-AlertingConfig -Path "CustomerNotifications.DiskUsage.EmailTemplate" -DefaultValue "<p>Your local storage is running low, with less than 10% remaining. To free up space, you might consider:<br><br>- Deleting unnecessary downloaded files<br>- Emptying the Recycle Bin<br>- Moving large files to cloud storage (e.g. OneDrive) and marking them as cloud-only.<br><br>If you're unable to resolve this issue or need further assistance, please reply to this email for support or call Aegis on 01865 393760.</p>") `
            -ErrorAction Stop
    }
    catch {
        Write-Host "Unable to find user '$Username'. Skipping sending Halo response."
    }
}

function Handle-HyperVReplicationAlert {
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

function Handle-PatchMonitorAlert {
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
            $entity = GetEntity -table $table -partitionKey $partitionKey -rowKey $rowKey

            if ($null -eq $entity) {
                # Create a new entity with an initial AlertCount of 1.
                # Use InsertOrMerge to handle race conditions where entity might be created by another process
                $entity = [Microsoft.Azure.Cosmos.Table.DynamicTableEntity]::new($partitionKey, $rowKey)
                $entity.Properties.Add("AlertCount", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForInt(1))
                $null = InsertOrMergeEntity -table $table -entity $entity
                
                # Re-fetch the entity to get current state after potential merge
                $entity = GetEntity -table $table -partitionKey $partitionKey -rowKey $rowKey
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

function Handle-BackupExecAlert {
    param ($HaloTicketCreate)

    Write-Host "Backup Exec Alert Detected"
    Write-Host "Creating Ticket"
    $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

function Handle-HostsAlert {
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
    $consolidatableTypes = Get-AlertingConfig -Path "AlertConsolidation.ConsolidatableAlertTypes" -DefaultValue @()
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
                Write-Host "Found single matching ticket for consolidation: ID $($matchingTickets[0].id)"
                return $matchingTickets[0]
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
        $currentNotes = Get-HaloTicket -TicketID $ExistingTicket.id -IncludeDetails
        $consolidationNotes = $currentNotes.actions | Where-Object { $_.note -like "*Additional $AlertType alert detected*" }
        $currentCount = $consolidationNotes.Count + 1 # +1 for the original ticket
        
        if ($currentCount -ge $maxCount) {
            Write-Warning "Maximum consolidation count ($maxCount) reached for ticket $($ExistingTicket.id). Creating new ticket instead."
            return $false
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

function Handle-DefaultAlert {
    param ($HaloTicketCreate)

    Write-Host "Creating Ticket without additional processing!"
    $null = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

# Export the public functions
Export-ModuleMember -Function @(
    'New-HaloTicketWithFallback',
    'New-MinimalTicketContent',
    'Get-WindowsErrorMessage',
    'Get-CustomErrorMessage',
    'Get-OnlineErrorMessage',
    'Handle-DiskUsageAlert',
    'Handle-HyperVReplicationAlert',
    'Handle-PatchMonitorAlert',
    'Handle-BackupExecAlert',
    'Handle-HostsAlert',
    'Handle-DefaultAlert',
    'Find-ExistingSecurityAlert',
    'Update-ExistingSecurityTicket',
    'Test-AlertConsolidation'
)