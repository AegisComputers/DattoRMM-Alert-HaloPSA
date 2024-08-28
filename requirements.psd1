# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    'DattoRMM' = '1.0.0.28'  # Datto RMM Module
    'HaloAPI' = '1.16.0'     # Halo API Module
    'Az.Accounts' = '3.0.3'  # For authentication and account management
    'Az.Storage' = '5.1.0'   # For Azure Storage operations
    'AzTable' = '2.1.0'      # For Azure Table Storage operations including Get-AzTableRow, Update-AzTableRow, and Remove-AzTableRow
    'Az' = '9.1.1'           # Ensuring the latest Az module version which includes all necessary dependencies
}
