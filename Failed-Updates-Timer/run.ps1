param($Timer)  # Accept the Timer trigger as a parameter

# Set environment variables and local variables
$storageAccountName = "dattohaloalertsstgnirab"
$storageAccountKey = $env:strKey
$tableName = "DevicePatchAlerts"

# Ensure the storage account key is set
if (-not $storageAccountKey) {
    Write-Error "Storage account key is not set. Please set the environment variable 'strKey'."
    exit 1
}

# Connect to Azure Storage
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$table = Get-StorageTable -Context $context -TableName $tableName

# Ensure the table is retrieved successfully
if (-not $table) {
    Write-Error "Failed to retrieve the storage table. Please check the storage account name and key."
    exit 1
}

# Define the threshold for row deletion, converted to UTC
$thresholdDate = (Get-Date).AddDays(-60).ToUniversalTime()

# Retrieve all entities from the table
$entities = Get-AzTableRowAll -Table $table

foreach ($entity in $entities) {
    try {
        # Convert entity timestamp (DateTimeOffset) to UTC DateTime object
        $entityTimestamp = $entity.TableTimestamp.UtcDateTime

        if ($entityTimestamp -lt $thresholdDate) {
            # Remove rows older than the threshold
            Remove-AzTableRow -Table $table -PartitionKey $entity.PartitionKey -RowKey $entity.RowKey
            Write-Host "Removed entity with RowKey: $($entity.RowKey) from PartitionKey: $($entity.PartitionKey)"
        }
    }
    catch {
        Write-Error "Failed to process entity with RowKey: $($entity.RowKey) from PartitionKey: $($entity.PartitionKey). Error: $_"
    }
}

# Log the end time
Write-Output "TimerTrigger function completed at: $(Get-Date)"
