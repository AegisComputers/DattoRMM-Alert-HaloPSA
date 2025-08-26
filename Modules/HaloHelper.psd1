@{
    # Module metadata
    RootModule = 'HaloHelper.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-f6a7-8901-2345-678901bcdefb'
    Author = 'Aegis Computer Maintenance Ltd'
    CompanyName = 'Aegis Computer Maintenance Ltd'
    Copyright = '(c) 2025 Aegis Computer Maintenance Ltd. All rights reserved.'
    Description = 'Helper functions for HaloPSA integration and client/site matching'
    
    # PowerShell version requirements
    PowerShellVersion = '7.2'
    
    # Required modules
    RequiredModules = @(
        'HaloAPI',
        'DattoRMM'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-HaloReport',
        'Find-DattoAlertHaloSite',
        'Find-DattoAlertHaloClient'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
}
