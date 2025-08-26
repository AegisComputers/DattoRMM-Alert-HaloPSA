#
# Module manifest for the 'EmailHelper' module
#

@{

# Script module file associated with this manifest.
RootModule = 'EmailHelper.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# A unique identifier for this module.
GUID = 'ab4f8d33-1c8a-4967-9c39-a4e268975e40'  # Replace with a generated GUID

# Author of this module.
Author = 'Oliver Perring'

# Company or vendor of this module.
CompanyName = 'Aegis Computers'

# Copyright statement for this module.
Copyright = '(c) 2024 Oliver Perring. All rights reserved.'

# Description of the functionality provided by this module.
Description = 'This module, HaloHelper, provides enhanced email handling and response functionalities for Halo services.'

# Minimum version of the Windows PowerShell engine required by this module.
PowerShellVersion = '7.2'

# Functions to export from this module.
FunctionsToExport = @('Get-HaloUserEmail', 'Send-HaloEmailResponse', 'Send-HaloUserResponse')

# Variables to export from this module.
VariablesToExport = '*'

# Aliases to export from this module.
AliasesToExport = @()

# List of all modules packaged with this module.
NestedModules = @()

# List of all files packaged with this module.
FileList = @('EmailHelper.psm1')

# Private data to pass to the module specified in RootModule/ModuleToProcess.
PrivateData = @{
    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Halo', 'Email', 'Automation')

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module.
        # ReleaseNotes = ''
    } # End of PSData hashtable
} # End of PrivateData hashtable

# HelpInfo URI of this module.
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
