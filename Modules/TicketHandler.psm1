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

# Function to look up HResult using Win32Exception
function Get-WindowsErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ErrorCode
    )

    $customErrorMessage = Get-CustomErrorMessage -ErrorCode $ErrorCode
    if ($customErrorMessage) {
        $errorMessage = $customErrorMessage
        return $errorMessage
    }
    
    # Try using Win32Exception to get a message
    try {
        $exception = New-Object System.ComponentModel.Win32Exception($ErrorCode)
        $errorMessage = $exception.Message
    } catch {
        $errorMessage = "Unknown error code or not a Win32 error."
    }
    
    # If no valid message found, fallback to a custom mapping
    if ($errorMessage -eq "Unknown error code or not a Win32 error.") {
        $customErrorMessage = Get-CustomErrorMessage -ErrorCode $ErrorCode
        if ($customErrorMessage) {
            $errorMessage = $customErrorMessage
        }
    }
    
    return $errorMessage
}

# Custom mapping for frequent errors (add more as necessary)
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
        0x8007000E = "E_OUTOFMEMORY: Failed to allocate necessary memory."
        0x80004001 = "E_NOTIMPL: Not implemented."
        0x80070020 = "ERROR_SHARING_VIOLATION: The process cannot access the file because it is being used by another process."
        0x80070050 = "ERROR_FILE_EXISTS: The file already exists."
        0x8007001F = "ERROR_GEN_FAILURE: A device attached to the system is not functioning."
        0x80070070 = "ERROR_DISK_FULL: There is not enough space on the disk."
        0x80070103 = "ERROR_NO_MORE_ITEMS: No more items are available."
        0x80070490 = "ERROR_NOT_FOUND: Element not found."
        0x8007139F = "ERROR_RESOURCE_NOT_PRESENT: The resource is not present."
        0x80070522 = "ERROR_PRIVILEGE_NOT_HELD: A required privilege is not held by the client."
        0x8009030E = "SEC_E_NO_CREDENTIALS: No credentials are available in the security package."
        0x80131904 = "COR_E_ARGUMENTOUTOFRANGE: Argument is out of range."
        0xC00D36B2 = "MF_E_UNSUPPORTED_BYTESTREAM_TYPE: The bytestream type is not supported."
        0x8007010B = "ERROR_DIRECTORY: The directory name is invalid."
        0x800705B4 = "ERROR_TIMEOUT: The operation timed out."
        0x80070570 = "ERROR_FILE_CORRUPT: The file or directory is corrupted and unreadable."
        0x80070008 = "ERROR_NOT_ENOUGH_MEMORY: Not enough storage is available to process this command."
        0x80070017 = "ERROR_CRC: Data error (cyclic redundancy check)."
        0x80070422 = "ERROR_SERVICE_DISABLED: The service cannot be started because it is disabled or because it has no enabled devices associated with it."
        0x8007045B = "ERROR_SHUTDOWN_IN_PROGRESS: A system shutdown is in progress."
        0x80072EE7 = "WININET_E_NAME_NOT_RESOLVED: The server name or address could not be resolved."
        0x8024402F = "WU_E_PT_ECP_SUCCEEDED_WITH_ERRORS: External cab processor found one or more errors."
        0xC0000005 = "STATUS_ACCESS_VIOLATION: The instruction at the referenced memory address could not be read."
        0xC0000017 = "STATUS_NO_MEMORY: Not enough virtual memory or paging file quota is available to complete the operation."
        0xC0000135 = "STATUS_DLL_NOT_FOUND: A DLL required for this process could not be found."
        0x80244012 = "WU_E_PT_DOUBLE_INITIALIZATION: Initialization failed because the object was already initialized."
        0x80244013 = "WU_E_PT_INVALID_COMPUTER_NAME: The computer name could not be determined."
        0x80244015 = "WU_E_PT_REFRESH_CACHE_REQUIRED: Server response requires refreshing the internal cache."
        0x80244019 = "WU_E_PT_HTTP_STATUS_NOT_FOUND: Same as HTTP 404 - the server could not find the requested resource."
        0x8024401C = "WU_E_PT_HTTP_STATUS_REQUEST_TIMEOUT: The server timed out waiting for the request."
        0x8024401F = "WU_E_PT_HTTP_STATUS_SERVER_ERROR: Internal server error prevented fulfilling the request."
        0x8024402A = "WU_E_PT_CONFIG_PROP_MISSING: A configuration property value was missing."
        0x8024200D = "WU_E_UH_INSTALLER_FAILURE: Update failed during installation."
        0x80248007 = "WU_E_DS_NODATA: The information requested is not available."
        0x80072F8F = "WININET_E_DECODING_FAILED: Content decoding has failed, possibly due to TLS misconfiguration."
        0x80072EFE = "WININET_E_CONNECTION_ABORTED: The connection to the server was closed abnormally."
        0x80073701 = "ERROR_SXS_ASSEMBLY_MISSING: The referenced assembly could not be found, likely due to a component store corruption."
    }

    
    return $errorDictionary[$ErrorCode]
}

function Handle-DiskUsageAlert {
    param ($Request, $HaloTicketCreate, $HaloClientDattoMatch)
    
    Write-Host "Alert detected for high disk usage on C: drive. Taking action..." 

    $AlertUID = $Request.Body.alertUID
    $AlertDetails = Get-DrmmAlert -alertUid $AlertUID
    $Device = Get-DrmmDevice -deviceUid $AlertDetails.alertSourceInfo.deviceUid
    $LastUser = $Device.lastLoggedInUser
    $Username = $LastUser -replace '^[^\\]*\\', ''

    Write-Host "Creating Ticket"
    $Ticket = New-HaloTicket -Ticket $HaloTicketCreate

    FindAndSendHaloResponse -Username $Username -ClientID $HaloClientDattoMatch -TicketId $ticket.id -EmailMessage "<p>Your local storage is running low, with less than 10% remaining. To free up space, you might consider:<br><br>- Deleting unnecessary downloaded files<br>- Emptying the Recycle Bin<br>- Moving large files to cloud storage (e.g. OneDrive) and marking them as cloud-only.<br><br>If you're unable to resolve this issue or need further assistance, please reply to this email for support or call Aegis on 01865 393760.</p>"
}

function Handle-HyperVReplicationAlert {
    param ($HaloTicketCreate)

    Write-Host "Alert detected for Hyper-V Replication. Taking action..."

    $TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("UTC")
    $CurrentTimeUTC = [System.DateTime]::UtcNow
    $UKTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("GMT Standard Time")
    $CurrentTimeUK = [System.TimeZoneInfo]::ConvertTimeFromUtc($CurrentTimeUTC, $UKTimeZone)

    $StartTime = [datetime]::new($CurrentTimeUK.Year, $CurrentTimeUK.Month, $CurrentTimeUK.Day, 9, 0, 0)
    $EndTime = [datetime]::new($CurrentTimeUK.Year, $CurrentTimeUK.Month, $CurrentTimeUK.Day, 17, 30, 0)

    if ($CurrentTimeUK -ge $StartTime -and $CurrentTimeUK -lt $EndTime) {
        Write-Output "The current time is between 9 AM and 5:30 PM UK time. A ticket will be created!"
        Write-Host "Creating Ticket"
        $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
    } else {
        Write-Output "The current time is outside of 9 AM and 5:30 PM UK time. No Ticket will be created!"
    }
}

function Handle-PatchMonitorAlert {
    param ($AlertWebhook, $HaloTicketCreate, $tableName)

    Write-Host "Alert detected for Patching. Taking action..."

    $AlertID = $AlertWebhook.alertUID
    $AlertDRMM = Get-DrmmAlert -alertUid $AlertID

    if ($AlertDRMM -ne $Null) {
        $Device = Get-DrmmDevice -deviceUid $AlertDRMM.alertSourceInfo.deviceUid
        $DeviceHostname = $Device.hostname

        $partitionKey = "DeviceAlert"
        $rowKey = $DeviceHostname

        $table = Get-StorageTable -tableName $tableName
        $entity = GetEntity -table $table -partitionKey $partitionKey -rowKey $rowKey

        if ($entity -eq $null) {
            $entity = [Microsoft.Azure.Cosmos.Table.DynamicTableEntity]::new($partitionKey, $rowKey)
            $entity.Properties.Add("AlertCount", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForInt(1))
            InsertOrMergeEntity -table $table -entity $entity
        } else {
            $entity.AlertCount++
            Update-AzTableRow -Table $table -entity $entity
        }

        $threshold = 2
        if ($entity.AlertCount -ge $threshold) {
            Write-Output "Alert count for $DeviceHostname has reached the threshold of $threshold."
            Write-Host "Creating Ticket"
            $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
            remove-AzTableRow -Table $table -PartitionKey $partitionKey -RowKey $rowKey
        }
    } else {
        Write-Host "Alert missing in Datto RMM no further action...."
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

