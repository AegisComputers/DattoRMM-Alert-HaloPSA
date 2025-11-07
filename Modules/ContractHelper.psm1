# ContractHelper.psm1
# Handles contract validation and ticket type assignment based on device type and contract coverage

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DeviceTypeFromAlert {
    <#
    .SYNOPSIS
    Determines if a device is a Server or PC/Workstation based on Datto device information.
    
    .PARAMETER DattoDevice
    The Datto device object containing device information
    
    .RETURNS
    String: "Server", "PC", or "Unknown"
    
    .NOTES
    Priority order:
    1. Trust Datto's deviceType field (Server/Desktop/Laptop)
    2. Use hostname patterns only as fallback (word boundaries to avoid false positives)
    3. Default to PC if uncertain (safer for billing)
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$DattoDevice
    )
    
    try {
        # PRIORITY 1: Trust Datto's deviceType.category field
        # Datto structure: $device.deviceType.category = "Server", "Laptop", "Desktop", "Workstation"
        #                  $device.deviceType.type = "Main System Chassis", etc.
        $deviceTypeCategory = $null
        
        # Handle both full device object and simplified hashtable
        if ($DattoDevice.deviceType) {
            if ($DattoDevice.deviceType -is [string]) {
                # Simple string (from alert webhook)
                $deviceTypeCategory = $DattoDevice.deviceType.Trim()
            }
            elseif ($DattoDevice.deviceType.category) {
                # Nested object from Get-DrmmDevice or Get-DrmmSiteDevices
                $deviceTypeCategory = $DattoDevice.deviceType.category.Trim()
            }
        }

        write-Host "Datto deviceType.category: $deviceTypeCategory"
        
        if ($deviceTypeCategory -and $deviceTypeCategory -ne "") {
            Write-Host "Datto deviceType.category: $deviceTypeCategory"
            
            # Map Datto device types to our categories
            if ($deviceTypeCategory -eq "Server") {
                Write-Host "Device identified as Server (Datto Category: $deviceTypeCategory)"
                return "Server"
            }
            elseif ($deviceTypeCategory -match "^(Desktop|Laptop|Workstation)$") {
                Write-Host "Device identified as PC (Datto Category: $deviceTypeCategory)"
                return "PC"
            }
            else {
                Write-Host "Unknown Datto device category '$deviceTypeCategory', will try hostname pattern matching"
            }
        }
        else {
            Write-Host "No deviceType.category found, will try hostname pattern matching"
        }
        
        # PRIORITY 2: Fallback to hostname patterns (with word boundaries to avoid false matches)
        if ($DattoDevice.hostname) {
            $hostname = $DattoDevice.hostname.ToUpper()
            
            # Server patterns: Use word boundaries and common server naming conventions
            # Examples: CL01-HYP01, DC01, SQL-PROD, HYP-HOST01, AC-SERVER
            # Patterns: cl\d+ (clusters), hyp (hypervisors), dc\d+ (domain controllers), 
            #           ac- followed by server indicators, sql, exch, etc.
            if ($hostname -match '\b(CL\d+|HYP|DC\d+|SQL|EXCH|ESX|VM-|HOST)\b' -or
                $hostname -match '^(SRV|SERVER)' -or
                $hostname -match '-SRV\b|-SERVER\b') {
                Write-Host "Device identified as Server based on hostname pattern: $hostname"
                return "Server"
            }
            
            # PC patterns: Use word boundaries to avoid matching within words like "accrington"
            # Examples: WKS01, DESK-USER, LAP-123, PC01, NB-001
            # Must start with or have hyphen before pattern to avoid "acc-lap" matching "lap"
            if ($hostname -match '^(WKS|DESK|LAP|PC\d+|NB)-' -or
                $hostname -match '^(WORKSTATION|DESKTOP|LAPTOP|NOTEBOOK)\b') {
                Write-Host "Device identified as PC based on hostname pattern: $hostname"
                return "PC"
            }
        }
        
        # PRIORITY 3: Default to PC if we can't determine (safer default for charging)
        Write-Warning "Could not determine device type, defaulting to PC"
        return "PC"
    }
    catch {
        Write-Warning "Error determining device type: $($_.Exception.Message)"
        return "Unknown"
    }
}

function Get-ContractDeviceSupport {
    <#
    .SYNOPSIS
    Extracts the CFDevicesSupported custom field value from a contract.
    
    .PARAMETER Contract
    The Halo contract object (must have been retrieved with -FullObjects)
    
    .RETURNS
    String: "All", "Servers", "PCs", or null if not found
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$Contract
    )
    
    try {
        # Find the CFDevicesSupported custom field
        $devicesSupported = $Contract.customfields | Where-Object { 
            $_.name -eq "CFDevicesSupported" 
        }
        
        if ($devicesSupported -and $devicesSupported.value) {
            # Extract the label from the value array
            $supportedLabel = $devicesSupported.value[0].label
            Write-Host "Contract $($Contract.ref) supports: $supportedLabel"
            return $supportedLabel
        }
        else {
            Write-Host "Contract $($Contract.ref) has no CFDevicesSupported field set - defaulting to 'All'"
            return "All"
        }
    }
    catch {
        Write-Warning "Error reading CFDevicesSupported field: $($_.Exception.Message) - defaulting to 'All'"
        return "All"
    }
}

function Test-DeviceContractEligibility {
    <#
    .SYNOPSIS
    Determines if a device is eligible for contract coverage based on device type and contract support.
    
    .PARAMETER DeviceType
    The device type: "Server", "PC", or "Unknown"
    
    .PARAMETER ContractDeviceSupport
    The contract's supported devices: "All", "Servers", "PCs", or null
    
    .RETURNS
    Boolean: $true if device is eligible for contract, $false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DeviceType,
        
        [Parameter(Mandatory)]
        [AllowNull()]
        [string]$ContractDeviceSupport
    )
    
    # No contract support defined = default to "All" (eligible for all devices)
    if ([string]::IsNullOrWhiteSpace($ContractDeviceSupport)) {
        Write-Host "Contract has no device support defined - defaulting to 'All' (eligible)"
        return $true
    }
    
    # "All" means all devices are covered
    if ($ContractDeviceSupport -eq "All") {
        Write-Host "Contract covers All devices - eligible"
        return $true
    }
    
    # Check if device type matches contract support
    if ($ContractDeviceSupport -eq "Servers" -and $DeviceType -eq "Server") {
        Write-Host "Server device matches Servers-only contract - eligible"
        return $true
    }
    
    if ($ContractDeviceSupport -eq "PCs" -and $DeviceType -eq "PC") {
        Write-Host "PC device matches PCs-only contract - eligible"
        return $true
    }
    
    # Device type doesn't match contract
    Write-Host "Device type '$DeviceType' does not match contract support '$ContractDeviceSupport' - not eligible"
    return $false
}

function Get-TicketTypeAndChargeRate {
    <#
    .SYNOPSIS
    Determines the appropriate ticket type ID and charge rate based on contract eligibility.
    
    .PARAMETER HasActiveContract
    Whether an active MSA/*M contract was found
    
    .PARAMETER IsDeviceEligible
    Whether the device is eligible under the contract's device support rules
    
    .PARAMETER ContractTicketTypeId
    The ticket type ID to use for contract tickets (default: 8)
    
    .PARAMETER NonContractTicketTypeId
    The ticket type ID to use for non-contract tickets (default: 9)
    
    .RETURNS
    Hashtable with TicketTypeId and ChargeRate properties
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$HasActiveContract,
        
        [Parameter(Mandatory)]
        [bool]$IsDeviceEligible,
        
        [int]$ContractTicketTypeId = 8,
        
        [int]$NonContractTicketTypeId = 9
    )
    
    $result = @{
        TicketTypeId = $NonContractTicketTypeId
        ChargeRate   = 0
        Reason       = ""
    }
    
    # Contract ticket: Has active contract AND device is eligible
    if ($HasActiveContract -and $IsDeviceEligible) {
        $result.TicketTypeId = $ContractTicketTypeId
        $result.ChargeRate = $null  # Use default contract rate
        $result.Reason = "Contract ticket - Active MSA found and device is eligible"
        Write-Host "✓ Contract Ticket: Type ID $ContractTicketTypeId, using contract rate"
    }
    # Non-contract scenarios
    elseif (-not $HasActiveContract) {
        $result.Reason = "Non-contract ticket - No active MSA found"
        Write-Host "⚠ Non-Contract Ticket: Type ID $NonContractTicketTypeId, charge rate 0 (no contract)"
    }
    elseif (-not $IsDeviceEligible) {
        $result.Reason = "Non-contract ticket - Device not eligible under contract device support"
        Write-Host "⚠ Non-Contract Ticket: Type ID $NonContractTicketTypeId, charge rate 0 (device not covered)"
    }
    
    return $result
}

function Get-ContractTicketingDecision {
    <#
    .SYNOPSIS
    Main function that orchestrates contract validation and returns ticketing decision.
    
    .PARAMETER Contracts
    Array of contracts retrieved with Get-HaloContract -FullObjects (REQUIRED to get custom fields like CFDevicesSupported)
    
    .PARAMETER HaloSiteID
    The Halo site ID to filter contracts
    
    .PARAMETER DattoDevice
    The Datto device object
    
    .PARAMETER ClientID
    The Halo client ID
    
    .NOTES
    - Contracts MUST be retrieved with -FullObjects flag to access custom fields
    - If CFDevicesSupported is not set on an MSA contract, defaults to "All" (supports all devices)
    - Returns ticket type 8 (contract) if device is eligible, type 9 (non-contract) otherwise
    
    .RETURNS
    Hashtable with TicketTypeId, ChargeRate, ContractId, DeviceType, IsEligible, and Reason
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Contracts,
        
        [Parameter(Mandatory)]
        [int]$HaloSiteID,
        
        [Parameter(Mandatory)]
        [PSObject]$DattoDevice,
        
        [Parameter(Mandatory)]
        [int]$ClientID,
        
        [int]$ContractTicketTypeId = 8,
        
        [int]$NonContractTicketTypeId = 9
    )
    
    Write-Host "=== Contract Ticketing Decision Process ==="
    
    $result = @{
        TicketTypeId = $NonContractTicketTypeId
        ChargeRate   = 0
        ContractId   = $null
        DeviceType   = "Unknown"
        IsEligible   = $false
        Reason       = "No contract found"
        ContractRef  = $null
    }
    
    try {
        # Step 1: Determine device type
        $deviceType = Get-DeviceTypeFromAlert -DattoDevice $DattoDevice
        $result.DeviceType = $deviceType
        
        # Step 2: Ensure $Contracts is always an array to avoid .Count property errors
        # Handle null, empty, and single-object cases
        if ($null -eq $Contracts -or $Contracts.Count -eq 0) {
            $contractsArray = @()
        }
        else {
            $contractsArray = @($Contracts)
        }
        
        # Filter contracts by site and ref pattern
        Write-Host "Filtering $($contractsArray.Count) contracts for site ID $HaloSiteID"
        
        # DEBUG: Show all contracts BEFORE filtering
        Write-Host "=== DEBUG: All Contracts Before Filtering ==="
        foreach ($contract in $contractsArray) {
            $refTrimmed = if ($contract.ref) { $contract.ref.Trim() } else { 'NULL' }
            Write-Host "  Contract ID: $($contract.id) | ref: '$refTrimmed' | site_id: $($contract.site_id) | Expected site: $HaloSiteID"
        }
        Write-Host "=== END DEBUG ==="
        
        # PRIORITY 1: Try to find exact site match first
        $filteredContracts = @($contractsArray | Where-Object {
                $matchesPattern = ($_.ref -like '*M' -or $_.ref -like '*MSA' -or $_.ref -like 'InternalWork')
                $matchesSite = ($_.site_id -eq $HaloSiteID)
                return ($matchesPattern -and $matchesSite)
            })
        
        if ($filteredContracts.Count -gt 0) {
            Write-Host "✓ Found $($filteredContracts.Count) contract(s) with EXACT site match (Priority 1)"
        }
        else {
            # PRIORITY 2: Try client-level contracts (site_id = 0 or null)
            Write-Host "No exact site match found, checking client-level contracts..."
            $filteredContracts = @($contractsArray | Where-Object {
                    $matchesPattern = ($_.ref -like '*M' -or $_.ref -like '*MSA' -or $_.ref -like 'InternalWork')
                    $isClientLevel = ($_.site_id -eq 0 -or $null -eq $_.site_id)
                    return ($matchesPattern -and $isClientLevel)
                })
            
            if ($filteredContracts.Count -gt 0) {
                Write-Host "✓ Found $($filteredContracts.Count) client-level contract(s) (Priority 2)"
            }
            else {
                # PRIORITY 3: Try site_id = -1 contracts (InternalWork or MSA/M contracts marked as internal)
                Write-Host "No client-level contracts found, checking site_id=-1 contracts..."
                $filteredContracts = @($contractsArray | Where-Object {
                        # Match ANY contract with site_id = -1, regardless of ref pattern
                        # This includes both InternalWork AND MSA/*M contracts at the internal level
                        $matchesPattern = ($_.ref -like '*M' -or $_.ref -like '*MSA' -or $_.ref -like 'InternalWork')
                        $isInternalSite = ($_.site_id -eq -1)
                        return ($matchesPattern -and $isInternalSite)
                    })
                
                if ($filteredContracts.Count -gt 0) {
                    Write-Host "✓ Found $($filteredContracts.Count) contract(s) with site_id=-1 (Priority 3)"
                }
                else {
                    # PRIORITY 4 (LAST RESORT): Try same client, different site
                    Write-Host "No InternalWork found, checking same-client contracts (last resort)..."
                    $filteredContracts = @($contractsArray | Where-Object {
                            $matchesPattern = ($_.ref -like '*M' -or $_.ref -like '*MSA')
                            # Any site_id that's not 0, -1, or null (different site under same client)
                            $isDifferentSiteInClient = ($_.site_id -ne 0 -and $_.site_id -ne -1 -and $null -ne $_.site_id)
                            return ($matchesPattern -and $isDifferentSiteInClient)
                        })
                    
                    if ($filteredContracts.Count -gt 0) {
                        Write-Host "⚠ Found $($filteredContracts.Count) contract(s) at different site(s) under same client (Priority 4 - Last Resort)"
                    }
                    else {
                        $result.Reason = "No MSA, *M, *MSA, or InternalWork contract found for this client"
                        Write-Host "⚠ $($result.Reason)"
                        return $result
                    }
                }
            }
        }
        
        # Step 3: Get the latest contract
        $latestContract = $filteredContracts | Sort-Object start_date -Descending | Select-Object -First 1
        Write-Host "Latest contract: $($latestContract.ref) (ID: $($latestContract.id))"
        
        # Step 4: Check if we already have full objects (contracts passed in with -FullObjects)
        # If latestContract has customfields, we already have the full object
        Write-Host "Checking contract object for custom fields..."
        $fullContract = $latestContract
        
        if (-not $fullContract.customfields) {
            # Need to retrieve full object
            Write-Host "Retrieving full contract object for device support validation..."
            try {
                $fullContract = Get-HaloContract -ClientID $ClientID -FullObjects | 
                Where-Object { $_.id -eq $latestContract.id } | 
                Select-Object -First 1
                
                if (-not $fullContract) {
                    Write-Warning "Could not retrieve full contract object, defaulting to 'All' device support"
                    # Don't fail - just assume "All" support
                    $fullContract = $latestContract
                    # Add empty customfields so Get-ContractDeviceSupport defaults to "All"
                }
            }
            catch {
                Write-Warning "Error retrieving full contract: $($_.Exception.Message). Defaulting to 'All' device support"
                $fullContract = $latestContract
            }
        }
        
        try {
            
            # Step 5: Check device support on contract
            $contractDeviceSupport = Get-ContractDeviceSupport -Contract $fullContract
            
            # Step 6: Test eligibility
            $isEligible = Test-DeviceContractEligibility -DeviceType $deviceType -ContractDeviceSupport $contractDeviceSupport
            
            # Step 7: Determine ticket type and charge rate
            $ticketingDecision = Get-TicketTypeAndChargeRate `
                -HasActiveContract $true `
                -IsDeviceEligible $isEligible `
                -ContractTicketTypeId $ContractTicketTypeId `
                -NonContractTicketTypeId $NonContractTicketTypeId
            
            # Step 8: Build final result
            $result.TicketTypeId = $ticketingDecision.TicketTypeId
            $result.ChargeRate = $ticketingDecision.ChargeRate
            $result.ContractId = $latestContract.id
            $result.ContractRef = $latestContract.ref
            $result.IsEligible = $isEligible
            $result.Reason = $ticketingDecision.Reason
            
        }
        catch {
            Write-Warning "Error during contract validation: $($_.Exception.Message)"
            $result.Reason = "Error validating contract: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Error "Error in contract decision process: $($_.Exception.Message)"
        $result.Reason = "Error: $($_.Exception.Message)"
    }
    
    Write-Host "=== Decision: Ticket Type ID $($result.TicketTypeId), Charge Rate: $(if($null -eq $result.ChargeRate){'Contract Rate'}else{$result.ChargeRate}) ==="
    Write-Host "Reason: $($result.Reason)"
    
    return $result
}

# Export functions
Export-ModuleMember -Function @(
    'Get-DeviceTypeFromAlert',
    'Get-ContractDeviceSupport',
    'Test-DeviceContractEligibility',
    'Get-TicketTypeAndChargeRate',
    'Get-ContractTicketingDecision'
)
