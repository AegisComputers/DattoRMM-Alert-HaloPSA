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
        $DattoSiteName
    )
    $dattoLookupString = $DattoSiteName

    #Process based on naming scheme in Datto <site>(<Customer>)
    $dataSiteDetails = $dattoLookupString.Split("(").Split(")")
    $DattoSite = $dataSiteDetails[0] 
    $DattoCustomer = $dataSiteDetails[1] 
    $HaloClientID = (Get-HaloClient -Search $DattoCustomer)[0].id
    #Does <site> exist in Halo if not select <Customer> and select the first ID
    if ($SiteInfo = Get-HaloSite -Search $dattosite -ClientID $HaloClientID) {
        Write-Host "Found Site with Client id of $($HaloClientID)"
        $HaloSiteID = $SiteInfo.id 
    } elseif ($SiteInfo = Get-HaloSite -Search $DattoCustomer) {
        Write-Host "No Site found defaulting to Customer for site lookup. Will Map to Site named : Head Office IF existing"
        if ($siteDrillD = ($siteinfo | Where-Object {$_.ClientSite_Name -match "Head Office"})) {
            Write-Host "Head Office found"
            $HaloSiteID = $siteDrillD.id
        } else {
            Write-Host "Head Office not found. Defaulting to first created site"
            $HaloSiteID = $SiteInfo[0].id
        }
    } else {
        Write-Host "No Valid Site or Customer Found Setting to Aegis Internal"
	    $HaloSiteID = 286
    }
    Write-Host "Selected Site Id of $($HaloSiteID)"

    return $HaloSiteID
}

function Find-DattoAlertHaloClient {
    param (
        $DattoSiteName
    )
    $dattoLookupString = $DattoSiteName

    #Process based on naming scheme in Datto <site>(<Customer>)
    $dataSiteDetails = $dattoLookupString.Split("(").Split(")")
    #$DattoSite = $dataSiteDetails[0] 
    $DattoCustomer = $dataSiteDetails[1] 
    $HaloClientID = (Get-HaloClient -Search $DattoCustomer)[0].id
    #Does <site> exist in Halo if not select <Customer> and select the first ID

    Write-Host "Selected Client Id of $($HaloClientID)"

    return $HaloClientID
}
