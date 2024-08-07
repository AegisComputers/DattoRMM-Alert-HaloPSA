# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    'DattoRMM' = '1.0.0.28'
    'HaloAPI' = '1.16.0'
    'Az.Accounts' = '2.*'  # For authentication and account management
    'Az.Storage' = '3.*'   # For Azure Storage operations
    'AzTable' = '2.*'      # For Azure Table Storage operations including Get-AzTableRow, Update-AzTableRow, and Remove-AzTableRow
    'Az' = '9.*'           # Ensuring the latest Az module version which includes all necessary dependencies
}
