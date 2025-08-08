@{
    # Module metadata
    RootModule = 'DattoRMMGenerator.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'd4e5f6a7-b8c9-0123-4567-890123defabc'
    Author = 'Aegis Computer Maintenance Ltd'
    CompanyName = 'Aegis Computer Maintenance Ltd'
    Copyright = '(c) 2025 Aegis Computer Maintenance Ltd. All rights reserved.'
    Description = 'DattoRMM alert content generation and formatting functions'
    
    # PowerShell version requirements
    PowerShellVersion = '5.1'
    
    # Required modules
    RequiredModules = @(
        'DattoRMM'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Get-DRMMAlertColour',
        'Get-DRMMAlertDetailsSection',
        'Get-DRMMDeviceDetailsSection',
        'Get-DRMMDeviceStatusSection',
        'Get-DRMMAlertHistorySection'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
}
