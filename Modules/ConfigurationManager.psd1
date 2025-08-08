@{
    # Module metadata
    RootModule = 'ConfigurationManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3d4e5f6-a7b8-9012-3456-789012cdefab'
    Author = 'Aegis Computer Maintenance Ltd'
    CompanyName = 'Aegis Computer Maintenance Ltd'
    Copyright = '(c) 2025 Aegis Computer Maintenance Ltd. All rights reserved.'
    Description = 'Configuration management functions for DattoRMM-HaloPSA alert integration'
    
    # PowerShell version requirements
    PowerShellVersion = '5.1'
    
    # Required modules
    RequiredModules = @()
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Initialize-AlertingConfiguration',
        'Get-AlertingConfig',
        'Set-AlertingConfig',
        'Save-AlertingConfiguration',
        'New-DefaultConfigurationFile',
        'Get-BusinessHoursConfig',
        'Test-AlertingConfiguration'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
}
