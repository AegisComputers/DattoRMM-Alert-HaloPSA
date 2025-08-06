# TicketHandler.ps1
# Set environment variables and local variables
$storageAccountName = "dattohaloalertsstgnirab"
$storageAccountKey = $env:strKey
$tableName = "DevicePatchAlerts"

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

    $errorDictionary = @{
        0x80240022 = "WU_E_ALL_UPDATES_FAILED: Operation failed for all updates."
        0x80070005 = "E_ACCESSDENIED: Access Denied, insufficient permissions."
        0x80004005 = "E_FAIL: Unspecified error, often related to file or registry issues."
        0x80070002 = "ERROR_FILE_NOT_FOUND: The system cannot find the file specified."
        0x80070003 = "ERROR_PATH_NOT_FOUND: The system cannot find the path specified."
        0x80070057 = "E_INVALIDARG: One or more arguments are invalid."
        0x8000FFFF = "E_UNEXPECTED: Unexpected failure."
        0x80070006 = "E_HANDLE: Invalid handle error, generally related to system resource issues."
    }

    return $errorDictionary[$ErrorCode]
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
            -EmailMessage "<p>Your local storage is running low, with less than 10% remaining. To free up space, you might consider:<br><br>- Deleting unnecessary downloaded files<br>- Emptying the Recycle Bin<br>- Moving large files to cloud storage (e.g. OneDrive) and marking them as cloud-only.<br><br>If you're unable to resolve this issue or need further assistance, please reply to this email for support or call Aegis on 01865 393760.</p>" `
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

    $TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("UTC")
    $CurrentTimeUTC = [System.DateTime]::UtcNow
    $UKTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("GMT Standard Time")
    $CurrentTimeUK = [System.TimeZoneInfo]::ConvertTimeFromUtc($CurrentTimeUTC, $UKTimeZone)

    # Check if today is Saturday or Sunday
    if ($CurrentTimeUK.DayOfWeek -eq [System.DayOfWeek]::Saturday -or $CurrentTimeUK.DayOfWeek -eq [System.DayOfWeek]::Sunday) {
        Write-Output "Today is $($CurrentTimeUK.DayOfWeek). No ticket will be created on weekends!"
        Set-DrmmAlertResolve -alertUid $alertUID
        return
    }

    # Define the working hours (adjusted to match the output message, here 9:00 AM)
    $StartTime = [datetime]::new($CurrentTimeUK.Year, $CurrentTimeUK.Month, $CurrentTimeUK.Day, 9, 0, 0)
    $EndTime = [datetime]::new($CurrentTimeUK.Year, $CurrentTimeUK.Month, $CurrentTimeUK.Day, 17, 30, 0)

    if ($CurrentTimeUK -ge $StartTime -and $CurrentTimeUK -lt $EndTime) {
        Write-Output "The current time is between 9 AM and 5:30 PM UK time. A ticket will be created!"
        Write-Host "Creating Ticket"
        $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
    } else {
        Write-Output "The current time is outside of 9 AM and 5:30 PM UK time. No ticket will be created!"
        Set-DrmmAlertResolve -alertUid $alertUID
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
        $partitionKey = "DeviceAlert"
        $rowKey = $DeviceHostname

        # Get the table reference.
        $table = Get-StorageTable -tableName $tableName
        
        # Use try-catch to handle potential race conditions in storage operations
        try {
            $entity = GetEntity -table $table -partitionKey $partitionKey -rowKey $rowKey

            if ($entity -eq $null) {
                # Create a new entity with an initial AlertCount of 1.
                # Use InsertOrMerge to handle race conditions where entity might be created by another process
                $entity = [Microsoft.Azure.Cosmos.Table.DynamicTableEntity]::new($partitionKey, $rowKey)
                $entity.Properties.Add("AlertCount", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForInt(1))
                $result = InsertOrMergeEntity -table $table -entity $entity
                
                # Re-fetch the entity to get current state after potential merge
                $entity = GetEntity -table $table -partitionKey $partitionKey -rowKey $rowKey
            } else {
                # Increment the alert count and update the entity.
                $entity.AlertCount++
                Update-AzTableRow -Table $table -entity $entity
            }

            # Check if the alert threshold is met or exceeded.
            $threshold = 2
            if ($entity.AlertCount -ge $threshold) {
                Write-Output "Alert count for $DeviceHostname has reached the threshold of $threshold."
                Write-Host "Creating Ticket"
                $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
                
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
            $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
        }
    } else {
        Write-Host "Alert missing in Datto RMM, no further action..."
    }
}

function Handle-BackupExecAlert {
    param ($HaloTicketCreate)

    Write-Host "Backup Exec Alert Detected"
    Write-Host "Creating Ticket"
    $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

function Handle-HostsAlert {
    param ($HaloTicketCreate)

    Write-Host "Hosts Alert Detected"
    Write-Host "Creating Ticket"
    $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}

function Handle-DefaultAlert {
    param ($HaloTicketCreate)

    Write-Host "Creating Ticket without additional processing!"
    $Ticket = New-HaloTicketWithFallback -HaloTicketCreate $HaloTicketCreate
}