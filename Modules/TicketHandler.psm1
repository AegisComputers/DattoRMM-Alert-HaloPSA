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

function Get-WindowsErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorCode
    )

    # Check for a custom error message first
    $customErrorMessage = Get-CustomErrorMessage -ErrorCode $ErrorCode
    if ($customErrorMessage) {
        return $customErrorMessage
    }

    # Try using Win32Exception to get a message
    try {
        $exception = New-Object System.ComponentModel.Win32Exception($ErrorCode)
        $errorMessage = $exception.Message
    } catch {
        Write-Debug "Failed to create Win32Exception for code $ErrorCode. Error: $_"
        $errorMessage = "Unknown error code or not a Win32 error."
    }

    # If the error message is the default message, attempt an online lookup.
    if ($errorMessage -eq "Unknown error code or not a Win32 error.") {
        $onlineErrorMessage = Get-OnlineErrorMessage -ErrorCode $ErrorCode
        if ($onlineErrorMessage) {
            $errorMessage = $onlineErrorMessage
        }
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
    $Ticket = New-HaloTicket -Ticket $HaloTicketCreate

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
        $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
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

    if ($AlertDRMM -ne $null) {
        # Retrieve the device details and extract the hostname.
        $Device = Get-DrmmDevice -deviceUid $AlertDRMM.alertSourceInfo.deviceUid
        $DeviceHostname = $Device.hostname

        # Define partition and row keys for table storage.
        $partitionKey = "DeviceAlert"
        $rowKey = $DeviceHostname

        # Get the table reference.
        $table = Get-StorageTable -tableName $tableName
        $entity = GetEntity -table $table -partitionKey $partitionKey -rowKey $rowKey

        if ($entity -eq $null) {
            # Create a new entity with an initial AlertCount of 1.
            $entity = [Microsoft.Azure.Cosmos.Table.DynamicTableEntity]::new($partitionKey, $rowKey)
            $entity.Properties.Add("AlertCount", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForInt(1))
            InsertOrMergeEntity -table $table -entity $entity
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
            $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
            # Clean up the record from the table after handling the alert.
            remove-AzTableRow -Table $table -PartitionKey $partitionKey -RowKey $rowKey
        }
    } else {
        Write-Host "Alert missing in Datto RMM, no further action..."
    }
}

function Handle-BackupExecAlert {
    param ($HaloTicketCreate)

    Write-Host "Backup Exec Alert Detected"
    Write-Host "Creating Ticket"
    $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
}

function Handle-HostsAlert {
    param ($HaloTicketCreate)

    Write-Host "Hosts Alert Detected"
    Write-Host "Creating Ticket"
    $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
}

function Handle-DefaultAlert {
    param ($HaloTicketCreate)

    Write-Host "Creating Ticket without additional processing!"
    $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
}