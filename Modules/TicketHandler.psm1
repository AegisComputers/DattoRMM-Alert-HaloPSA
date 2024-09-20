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

        $threshold = 3
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

function Handle-DefaultAlert {
    param ($HaloTicketCreate)

    Write-Host "Creating Ticket without additional processing!"
    $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
}
