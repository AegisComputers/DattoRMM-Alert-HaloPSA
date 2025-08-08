# HaloHelper Module - HaloPSA API integration and report management
Set-StrictMode -Version Latest

function Invoke-HaloReport {
    param (
        $Report,
        [Switch]$IncludeReport
    )
	# This will check for a Halo report. Create it if it doesn't exist and return the results if it does
	$HaloReportBase = Get-HaloReport -Search $report.name
	$FoundReportCount = ($HaloReportBase | Measure-Object).Count

	if ($FoundReportCount -eq 0) {
		$HaloReportBase = New-HaloReport -Report $report
	} elseif ($FoundReportCount -gt 1) {
		# Handle multiple reports gracefully - use the first one and log a warning instead of throwing
		Write-Warning "Found multiple reports with the name '$($report.name)'. Using the first one. Consider cleaning up duplicate reports."
		$HaloReportBase = $HaloReportBase[0]
	}

    if ($IncludeReport) {
        $HaloResults = (Get-HaloReport -ReportID $HaloReportBase.id -LoadReport).report.rows
    } else {
        $HaloResults = $HaloReportBase
    }
	
	return $HaloResults
}

function Find-DattoAlertHaloSite {
    param (
        $DattoSiteName
    )
    try {
        $dattoLookupString = $DattoSiteName

        #Process based on naming scheme in Datto <site>(<Customer>)
        $dataSiteDetails = $dattoLookupString.Split("(").Split(")")
        $DattoSite = $dataSiteDetails[0] 
        $DattoCustomer = $dataSiteDetails[1] 
        
        # Add error handling for client lookup
        $HaloClients = Get-HaloClient -Search $DattoCustomer
        $defaultSiteId = Get-AlertingConfig -Path "TicketDefaults.DefaultSiteId" -DefaultValue 286
        $defaultClientName = Get-AlertingConfig -Path "TicketDefaults.DefaultClientName" -DefaultValue "Aegis Internal"
        
        if (-not $HaloClients -or $HaloClients.Count -eq 0) {
            Write-Warning "No Halo client found for '$DattoCustomer'. Using $defaultClientName ($defaultSiteId)."
            return $defaultSiteId
        }
        $HaloClientID = $HaloClients[0].id
        
        #Does <site> exist in Halo if not select <Customer> and select the first ID
        if ($SiteInfo = Get-HaloSite -Search $DattoSite -ClientID $HaloClientID) {
            Write-Host "Found Site with Client id of $($HaloClientID)"
            $HaloSiteID = $SiteInfo[0].id 
        } elseif ($SiteInfo = Get-HaloSite -Search $DattoCustomer) {
            Write-Host "No Site found defaulting to Customer for site lookup. Will Map to Site named : Head Office IF existing"
            if ($siteDrillD = ($SiteInfo | Where-Object {$_.ClientSite_Name -match "Head Office"})) {
                Write-Host "Head Office found"
                $HaloSiteID = $siteDrillD[0].id
            } else {
                Write-Host "Head Office not found. Defaulting to first created site"
                $HaloSiteID = $SiteInfo[0].id
            }
        } else {
            Write-Host "No Valid Site or Customer Found Setting to $defaultClientName"
            $HaloSiteID = $defaultSiteId
        }
        Write-Host "Selected Site Id of $($HaloSiteID)"

        return $HaloSiteID
    } catch {
        $defaultSiteId = Get-AlertingConfig -Path "TicketDefaults.DefaultSiteId" -DefaultValue 286
        $defaultClientName = Get-AlertingConfig -Path "TicketDefaults.DefaultClientName" -DefaultValue "Aegis Internal"
        Write-Warning "Error in site lookup for '$DattoSiteName': $($_.Exception.Message). Using $defaultClientName ($defaultSiteId)."
        return $defaultSiteId
    }
}

function Find-DattoAlertHaloClient {
    param (
        $DattoSiteName
    )
    try {
        $dattoLookupString = $DattoSiteName
        #Process based on naming scheme in Datto <site>(<Customer>)
        $dataSiteDetails = $dattoLookupString.Split("(").Split(")")
        $DattoCustomer = $dataSiteDetails[1] 
        
        # Add error handling for client lookup
        $HaloClients = Get-HaloClient -Search $DattoCustomer
        if (-not $HaloClients -or $HaloClients.Count -eq 0) {
            Write-Warning "No Halo client found for '$DattoCustomer'."
            return $null
        }
        $HaloClientID = $HaloClients[0].id

        Write-Host "Selected Client Id of $($HaloClientID)"

        return $HaloClientID
    } catch {
        Write-Warning "Error in client lookup for '$DattoSiteName': $($_.Exception.Message)"
        return $null
    }
}

# Export the public functions
Export-ModuleMember -Function @(
    'Invoke-HaloReport',
    'Find-DattoAlertHaloSite',
    'Find-DattoAlertHaloClient'
)