# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    'DattoRMM' = '1.0.0.32'  # Datto RMM Module - Updated for PowerShell 7.2
    'HaloAPI' = '1.22.1'     # Halo API Module - Updated for PowerShell 7.2
    'Az.Accounts' = '5.2.0'  # For authentication and account management - Updated for PowerShell 7.2
    'Az.Storage' = '9.1.0'   # For Azure Storage operations - Updated for PowerShell 7.2
    'AzTable' = '2.1.0'      # For Azure Table Storage operations including Get-AzTableRow, Update-AzTableRow, and Remove-AzTableRow
    'Az' = '14.3.0'          # Ensuring the latest Az module version which includes all necessary dependencies - Updated for PowerShell 7.2
}
