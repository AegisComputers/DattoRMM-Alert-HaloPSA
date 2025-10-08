@{
    RootModule        = 'ContractHelper.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a5f8d3e1-9c2b-4a7d-8e1f-6b3c4d5e6f7a'
    Author            = 'Aegis Computer Maintenance'
    CompanyName       = 'Aegis Computer Maintenance Ltd'
    Copyright         = '(c) 2025 Aegis Computer Maintenance Ltd. All rights reserved.'
    Description       = 'Handles contract validation and ticket type assignment based on device type and contract coverage'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-DeviceTypeFromAlert',
        'Get-ContractDeviceSupport',
        'Test-DeviceContractEligibility',
        'Get-TicketTypeAndChargeRate',
        'Get-ContractTicketingDecision'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Halo', 'Datto', 'Contracts', 'Ticketing')
            ProjectUri = 'https://github.com/OliverPerring/DattoRMM-Alert-HaloPSA'
        }
    }
}
