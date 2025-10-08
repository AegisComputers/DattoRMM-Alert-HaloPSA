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
    #>
    param(
        [Parameter(Mandatory)]
        [PSObject]$DattoDevice
    )
    
    try {
        # Check device type from Datto
        # Datto typically uses 'deviceType' field: "Server", "Workstation", "Laptop", "Desktop", etc.
        if ($DattoDevice.deviceType) {
            $deviceType = $DattoDevice.deviceType
            
            # Map Datto device types to our categories
            if ($deviceType -match "Server|Domain Controller|Hyper-V|ESXi") {
                Write-Host "Device identified as Server (Type: $deviceType)"
                return "Server"
            }
            elseif ($deviceType -match "Workstation|Desktop|Laptop|PC") {
                Write-Host "Device identified as PC (Type: $deviceType)"
                return "PC"
            }
        }
        
        # Fallback: Check hostname patterns
        if ($DattoDevice.hostname) {
            $hostname = $DattoDevice.hostname
            
            # Common server naming patterns: SRV, SERVER, DC, SQL, EXCH, etc.
            if ($hostname -match "^(SRV|SERVER|DC|SQL|EXCH|HYP|ESX|VM|HOST)") {
                Write-Host "Device identified as Server based on hostname pattern: $hostname"
                return "Server"
            }
            # Common workstation patterns: WKS, DESK, LAP, PC
            elseif ($hostname -match "^(WKS|DESK|LAP|PC|NB)") {
                Write-Host "Device identified as PC based on hostname pattern: $hostname"
                return "PC"
            }
        }
        
        # Default to PC if we can't determine (safer default for charging)
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
        
        # Step 2: Filter contracts by site and ref pattern
        Write-Host "Filtering $($Contracts.Count) contracts for site ID $HaloSiteID"
        $filteredContracts = $Contracts | Where-Object {
            ($_.ref -like '*M' -and $_.site_id -eq $HaloSiteID) -or
            ($_.ref -like 'InternalWork' -and $_.site_id -eq $HaloSiteID)
        }
        
        Write-Host "Found $($filteredContracts.Count) MSA/*M contracts"
        
        if ($filteredContracts.Count -eq 0) {
            $result.Reason = "No MSA or *M contract found for this site"
            Write-Host "⚠ $($result.Reason)"
            return $result
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
