#
# Module manifest for module 'TicketHandler'
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'TicketHandler.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a8c72e45-2b3f-4d17-9e8a-f7b1c4d5e6a2'

    # Author of this module
    Author = 'Oliver Perring'

    # Company or vendor of this module
    CompanyName = 'Aegis Computer Maintenance Ltd'

    # Copyright statement for this module
    Copyright = '(c) 2025 Aegis Computer Maintenance Ltd. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Handles ticket processing and alert management for DattoRMM-HaloPSA integration'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.2'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'New-HaloTicketWithFallback',
        'New-MinimalTicketContent',
        'Get-WindowsErrorMessage',
        'Get-CustomErrorMessage',
        'Get-OnlineErrorMessage',
        'Invoke-DiskUsageAlert',
        'Invoke-HyperVReplicationAlert',
        'Invoke-PatchMonitorAlert',
        'Invoke-BackupExecAlert',
        'Invoke-HostsAlert',
        'Invoke-DefaultAlert',
        'Find-ExistingSecurityAlert',
        'Update-ExistingSecurityTicket',
        'Test-AlertConsolidation'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @()

    # Required modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'HaloAPI'
            ModuleVersion = '1.16.0'
        },
        @{
            ModuleName = 'DattoRMM'
            ModuleVersion = '1.0.0.28'
        },
        @{
            ModuleName = 'Az.Storage'
            ModuleVersion = '5.1.0'
        }
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('DattoRMM', 'HaloPSA', 'TicketManagement', 'Alerting')

            # A URL to the license for this module
            LicenseUri = ''

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/OliverPerring/DattoRMM-Alert-HaloPSA'

            # Release notes of this module
            ReleaseNotes = @'
## 2.0.0
### Changed
- Renamed Handle-* functions to Invoke-* for PowerShell best practices
- Enhanced error handling with retry logic and detailed logging
- Improved module dependency management
- Added comprehensive input validation

### Fixed
- Fixed Halo API search bug with device names ending in numbers
- Improved alert consolidation reliability
- Better error reporting and debugging capabilities

### Security
- Enhanced input validation and sanitization
- Improved error message handling to prevent information disclosure
'@
        }
    }
}
