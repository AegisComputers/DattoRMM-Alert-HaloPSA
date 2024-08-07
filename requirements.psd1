# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    'DattoRMM' = '1.0.0.28'# For Datto RMM
    'HaloAPI' = '1.16.0'   # For Halo PSA
    'Az.Accounts' = '2.*'  # For authentication and account management
    'Az.Storage' = '5.*'   # For Azure Storage operations
    'AzTable' = '2.*'      # For Azure Table Storage operations including Get-AzTableRow
}
