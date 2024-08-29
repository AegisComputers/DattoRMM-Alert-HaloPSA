# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.

# Set environment variables and local variables
$storageAccountName = "dattohaloalertsstgnirab"
$storageAccountKey = $env:strKey
$tableName = "DevicePatchAlerts"

# Log the start time for reference
$coldStartTime = Get-Date
Write-Host "Function App cold start at: $coldStartTime"

#Custom Modules
foreach($file in Get-ChildItem -Path "$PSScriptRoot\Modules" -Filter *.psm1){
    try {
        Import-Module $file.FullName
        Write-Host "Module $($file.Name) loaded successfully."
    } catch {
        Write-Host "Failed to load module $($file.Name). Error: $_"
        throw
    }
}

#Installed Modules
Import-module DattoRMM
Import-Module HaloAPI
Import-Module Az.Accounts
Import-Module Az.Storage
Import-Module AzTable

# Azure Table Existence and Connectivity Test
Write-Host "Testing Azure Table existence and connectivity..."

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# Log the end time for reference
$coldEndTime = Get-Date
$coldTotalTime = $coldEndTime - $coldStartTime
Write-Host "Function App cold start completed at: $coldEndTime"
Write-Host "Total cold start time: $($coldTotalTime.TotalSeconds) seconds"

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.

