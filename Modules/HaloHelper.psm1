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
		throw "Found more than one report with the name '$($HaloContactReportBase.name)'. Please delete all but one and try again."
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
        [string]$DattoSiteName
    )

    # Validate input
    if (-not $DattoSiteName) {
        throw "DattoSiteName cannot be null or empty."
    }

    # Split DattoSiteName into Site and Customer components
    $dataSiteDetails = $DattoSiteName -split '[()]'
    if ($dataSiteDetails.Count -lt 2) {
        throw "DattoSiteName format is invalid. Expected format: '<site>(<Customer>)'."
    }

    $DattoSite = $dataSiteDetails[0].Trim()
    $DattoCustomer = $dataSiteDetails[1].Trim()

    # Retrieve Halo Client ID
    $haloClient = Get-HaloClient -Search $DattoCustomer
    if (-not $haloClient) {
        throw "Halo client '$DattoCustomer' not found."
    }
    $HaloClientID = $haloClient[0].id

    # Try to find the site by the specific name
    $SiteInfo = Get-HaloSite -Search $DattoSite -ClientID $HaloClientID

    if ($SiteInfo) {
        Write-Host "Found site with client ID: $HaloClientID"
        return $SiteInfo.id
    }

    # If site not found by name, attempt to find by customer
    $SiteInfo = Get-HaloSite -Search $DattoCustomer -ClientID $HaloClientID
    if ($SiteInfo) {
        Write-Host "No site found by name. Defaulting to search by customer: $DattoCustomer"
        
        $HeadOfficeSite = $SiteInfo | Where-Object { $_.ClientSite_Name -match "Head Office" }
        if ($HeadOfficeSite) {
            Write-Host "Head Office found."
            return $HeadOfficeSite.id
        } else {
            Write-Host "Head Office not found. Defaulting to the first site found."
            return $SiteInfo[0].id
        }
    }

    # If no site or customer found, default to a known internal site
    Write-Host "No valid site or customer found. Defaulting to Aegis Internal."
    return 286
}


function Find-DattoAlertHaloClient {
    param (
        [string]$DattoSiteName
    )

    # Validate input
    if (-not $DattoSiteName) {
        throw "DattoSiteName cannot be null or empty."
    }

    # Split DattoSiteName into Site and Customer components
    $dataSiteDetails = $DattoSiteName -split '[()]'
    if ($dataSiteDetails.Count -lt 2) {
        throw "DattoSiteName format is invalid. Expected format: '<site>(<Customer>)'."
    }

    # Extract customer name
    $DattoCustomer = $dataSiteDetails[1].Trim()

    # Retrieve Halo Client ID
    $haloClient = Get-HaloClient -Search $DattoCustomer
    if (-not $haloClient) {
        throw "Halo client '$DattoCustomer' not found."
    }
    $HaloClientID = $haloClient[0].id

    Write-Host "Selected Client Id of $HaloClientID"

    return $HaloClientID
}

