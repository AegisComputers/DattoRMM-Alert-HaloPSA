@{
    # Module metadata
    RootModule = 'CoreHelper.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    Author = 'Aegis Computer Maintenance Ltd'
    CompanyName = 'Aegis Computer Maintenance Ltd'
    Copyright = '(c) 2025 Aegis Computer Maintenance Ltd. All rights reserved.'
    Description = 'Core helper functions for DattoRMM alert processing and Halo integration'
    
    # PowerShell version requirements
    PowerShellVersion = '7.2'
    
    # Required modules
    RequiredModules = @(
        'Az.Storage',
        'DattoRMM',
        'HaloAPI'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Get-MapColour',
        'Get-HeatMap', 
        'Get-DecodedTable',
        'Get-AlertDescription',
        'Get-AlertHaloType',
        'Get-HTMLBody',
        'Get-AlertEmailBody',
        'Get-StorageContext',
        'Get-StorageTable',
        'Add-StorageEntity',
        'Get-StorageEntity',
        'Optimize-HtmlContentForTicket'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
}
