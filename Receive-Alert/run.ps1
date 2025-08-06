using namespace System.Net
using namespace Microsoft.Azure.Cosmos.Table

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

Write-Host "Processing Webhook for Alert with the UID of - $($Request.Body.alertUID) -"

#Respond Request Ok
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Accepted
        Body       = 'Request accepted. Processing in the background.'
    })

#Halo Vars
$HaloClientID = $env:HaloClientID
$HaloClientSecret = $env:HaloClientSecret
$HaloURL = $env:HaloURL
$HaloTicketStatusID = $env:HaloTicketStatusID
$HaloCustomAlertTypeField = $env:HaloCustomAlertTypeField
$HaloTicketType = $env:HaloTicketType
$HaloReocurringStatus = $env:HaloReocurringStatus

#AZStorageVars
$tableName = Get-AlertingConfig -Path "Storage.TableName" -DefaultValue "DevicePatchAlerts"

#Datto Vars
$DattoURL = $env:DattoURL
$DattoKey = $env:DattoKey
$DattoSecretKey = $env:DattoSecretKey
$DattoAlertUIDField = $env:DattoAlertUIDField

$paramsDatto = @{
   Url       = $DattoURL
   Key       = $DattoKey
   SecretKey = $DattoSecretKey
}

Set-DrmmApiParameters @paramsDatto

# Get configuration values for potential future use
# $SetTicketResponded = Get-AlertingConfig -Path "TicketDefaults.SetTicketResponded" -DefaultValue $true
# $RelatedAlertMinutes = Get-AlertingConfig -Path "AlertThresholds.RelatedAlertWindowMinutes" -DefaultValue 5
# $ReoccurringTicketHours = Get-AlertingConfig -Path "AlertThresholds.ReoccurringTicketHours" -DefaultValue 24
# $HaloAlertHistoryDays = Get-AlertingConfig -Path "AlertThresholds.HaloAlertHistoryDays" -DefaultValue 30

#Priority Mapping from configuration
$PriorityHaloMap = Get-AlertingConfig -Path "PriorityMapping" -DefaultValue @{
    "Critical"    = "4"
    "High"        = "4"
    "Moderate"    = "4"
    "Low"         = "4"
    "Information" = "4"
}

#AlertWebhook Body
$AlertWebhook = $Request.Body

$Email = Get-AlertEmailBody -AlertWebhook $AlertWebhook

if ($Email) {
    $Alert = $Email.Alert

    #Connect to the halo api with the env vars
    Connect-HaloAPI -URL $HaloURL -ClientId $HaloClientID -ClientSecret $HaloClientSecret -Scopes "all"
    
    # Check if Device Report already exists, if not create it
    $ExistingDeviceReports = Get-HaloReport -Search "Datto RMM Improved Alerts PowerShell Function - Device Report"
    if ($ExistingDeviceReports -and $ExistingDeviceReports.Count -gt 0) {
        $HaloDeviceReport = $ExistingDeviceReports[0]
        Write-Host "Using existing Device Report with ID: $($HaloDeviceReport.id)"
    } else {
        $HaloDeviceReport = @{
            name                    = "Datto RMM Improved Alerts PowerShell Function - Device Report"
            sql                     = "Select did, Dsite, DDattoID, DDattoAlternateId from device"
            description             = "This report is used to quickly obtain device mapping information for use with the improved Datto RMM Alerts Function"
            type                    = 0
            datasource_id           = 0
            canbeaccessedbyallusers = $false
        }
        $HaloDeviceReport = New-HaloReport -Report $HaloDeviceReport
        Write-Host "Created new Device Report with ID: $($HaloDeviceReport.id)"
    }
    $ParsedAlertType = Get-AlertHaloType -Alert $Alert -AlertMessage $AlertWebhook.alertMessage

    $HaloDevice = Invoke-HaloReport -Report $HaloDeviceReport -IncludeReport | where-object { $_.DDattoID -eq $Alert.alertSourceInfo.deviceUid }

    # Check if Alerts Report already exists, if not create it
    $ExistingAlertsReports = Get-HaloReport -Search "Datto RMM Improved Alerts PowerShell Function - Alerts Report"
    if ($ExistingAlertsReports -and $ExistingAlertsReports.Count -gt 0) {
        $HaloAlertsReportBase = $ExistingAlertsReports[0]
        Write-Host "Using existing Alerts Report with ID: $($HaloAlertsReportBase.id)"
    } else {
        $HaloAlertsReportBase = @{
            name                    = "Datto RMM Improved Alerts PowerShell Function - Alerts Report"
            sql                     = "SELECT Faultid, Symptom, tstatusdesc, dateoccured, inventorynumber, FGFIAlertType, CFDattoAlertType, fxrefto as ParentID, fcreatedfromid as RelatedID FROM FAULTS inner join TSTATUS on Status = Tstatus Where CFDattoAlertType is not null and fdeleted <> 1"
            description             = "This report is used to quickly obtain alert information for use with the improved Datto RMM Alerts Function"
            type                    = 0
            datasource_id           = 0
            canbeaccessedbyallusers = $false
        }
        $HaloAlertsReportBase = New-HaloReport -Report $HaloAlertsReportBase
        Write-Host "Created new Alerts Report with ID: $($HaloAlertsReportBase.id)"
    }

    # $HaloAlertsReport = Invoke-HaloReport -Report $HaloAlertsReportBase

    # Alert report filtering for potential future correlation logic
    # $AlertReportFilter = @{
    #     id                       = $HaloAlertsReport.id
    #     filters                  = @(
    #         @{
    #             fieldname      = 'inventorynumber'
    #             stringruletype = 2
    #             stringruletext = "$($HaloDevice.did)"
    #         }
    #     )
    #     _loadreportonly          = $true
    #     reportingperiodstartdate = get-date(((Get-date).ToUniversalTime()).adddays(-$HaloAlertHistoryDays)) -UFormat '+%Y-%m-%dT%H:%M:%SZ'
    #     reportingperiodenddate   = get-date((Get-date -Hour 23 -Minute 59 -second 59).ToUniversalTime()) -UFormat '+%Y-%m-%dT%H:%M:%SZ'
    #     reportingperioddatefield = "dateoccured"
    #     reportingperiod          = "7"
    # }

    # Retrieve the report rows from a Halo report based on the given alert report filter
    # $ReportResults = (Set-HaloReport -Report $AlertReportFilter).report.rows

    # Filter the report results to find any history of recurring alerts that match the specific alert type
    # $ReoccuringHistory = $ReportResults | where-object { $_.CFDattoAlertType -eq $ParsedAlertType } 
    
    # Further filter the recurring alerts to find those that occurred within the specified time frame
    # $ReoccuringAlerts = $ReoccuringHistory | where-object { $_.dateoccured -gt ((Get-Date).addhours(-$ReoccurringTicketHours)) }

    # Find related alerts that occurred within a different specified time frame and are of a different alert type
    # $RelatedAlerts = $ReportResults | where-object { $_.dateoccured -gt ((Get-Date).addminutes(-$RelatedAlertMinutes)).ToUniversalTime() -and $_.CFDattoAlertType -ne $ParsedAlertType }
    
    # Capture the subject of the email alert
    $TicketSubject = $Email.Subject

    # Capture the body content of the email alert in HTML format
    $HTMLBody = $Email.Body
    
    # Handle large HTML content intelligently to preserve critical data
    $MaxBodyLength = Get-AlertingConfig -Path "AlertThresholds.HtmlBodyMaxLength" -DefaultValue 3000000
    $OriginalBodyLength = $HTMLBody.Length
    
    if ($OriginalBodyLength -gt $MaxBodyLength) {
        Write-Host "HTML body is large ($OriginalBodyLength characters). Optimizing for API transmission..."
        
        # Use helper function to optimize HTML content
        $HTMLBody = Optimize-HtmlContentForTicket -OriginalHtml $HTMLBody -MaxLength $MaxBodyLength -Request $Request -TicketSubject $TicketSubject
        
        Write-Host "Final HTML body size: $($HTMLBody.Length) characters (reduced from $OriginalBodyLength)"
    }

    # Map the priority of the alert to the corresponding Halo priority using the priority mapping
    $HaloPriority = $PriorityHaloMap."$($Alert.Priority)"

    # Retrieve the site details from the request body (Datto site details)
    $RSiteDetails = $Request.Body.dattoSiteDetails

    # Find the Halo site ID associated with the Datto site name provided in the site details
    $HaloSiteIDDatto = Find-DattoAlertHaloSite -DattoSiteName ($RSiteDetails)

    Write-Host ("Found Halo site with ID - $($HaloSiteIDDatto)")

    # Store the Datto site details from the request body into a variable
    $dattoLookupString = $Request.Body.dattoSiteDetails

    #Process based on naming scheme in Datto <site>(<Customer>)
    $dataSiteDetails = $dattoLookupString.Split("(").Split(")")
    $DattoCustomer = $dataSiteDetails[1] 
    $HaloClientID = (Get-HaloClient -Search $DattoCustomer)[0].id

    $HaloClientDattoMatch = $HaloClientID
    
    Write-Host "Client ID in Halo - $($HaloClientDattoMatch)"
    
    $Contracts = (Get-HaloContract -ClientID $HaloClientDattoMatch -FullObjects)

    Write-Host "Contracts for client ID - $($Contracts)"

    $FilteredContracts = $Contracts | Where-Object { #Internal work ref to stop false contracts selection from Halo when finishing internal alerts 
        ($_.ref -like '*M' -and $_.site_id -eq $HaloSiteIDDatto) -or
		($_.ref -like 'InternalWork' -and $_.site_id -eq $HaloSiteIDDatto)
    }

    # Sort the filtered contracts by 'start_date' in descending order
    $LatestContract = $FilteredContracts | Sort-Object start_date -Descending | Select-Object -First 1

    # Extract and display the ID of the latest contract based on the start date
    $LatestContractId = $LatestContract.id

    Write-Host "The latest contract is - $($LatestContract) with an id of $($LatestContract.id)" 

    $HaloTicketCreate = @{
        summary          = $TicketSubject
        tickettype_id    = Get-AlertingConfig -Path "TicketDefaults.TicketTypeId" -DefaultValue 8
        details_html     = $HtmlBody
        DattoAlertState  = 0
        site_id          = $HaloSiteIDDatto
        assets           = @(@{id = $HaloDevice.did })
        priority_id      = $HaloPriority
        status_id        = $HaloTicketStatusID
        category_1       = Get-AlertingConfig -Path "TicketDefaults.Category1" -DefaultValue "Datto Alert"
        contract_id      = $LatestContractId
        customfields     = @(
            @{
                id    = $HaloCustomAlertTypeField
                value = $ParsedAlertType
            };
            @{
                id    = $DattoAlertUIDField
                value = $Request.Body.alertUID
            }
        )
    }

    # Your command to get tickets
    $TicketidGet = Get-HaloTicket -Category1 145 -OpenOnly -FullObjects

    # The UID you are looking for
    $targetUID = $Request.Body.alertUID

    # Iterate over each ticket in the result
    foreach ($ticket in $TicketidGet) {
        # Access the custom fields
        $customFields = $ticket.customfields

        # Find the field with name 'CFDattoAlertUID'
        $dattoAlertUIDField = $customFields | Where-Object { $_.name -eq 'CFDattoAlertUID' }

        # Check if the value of this field matches the target UID
        if ($dattoAlertUIDField -and $dattoAlertUIDField.value -eq $targetUID) {
            # Output the matching ticket ID
            Write-Output "Found matching ticket: ID is $($ticket.id)"
            $ticketidHalo = $ticket.id
            $dateArrival = (get-date((get-date).AddMinutes(-5)))
            $dateEnd = (get-date) 
            Write-Output "Date Arrival $($dateArrival) and end $($dateEnd)"
            
            $ActionUpdate = @{
                ticket_id         = $ticket.id
                actionid          = 23
                outcome           = "Remote"
                outcome_id        = 23
                note              = "Resolved by Datto Automation"
                actionarrivaldate = $dateArrival
                actioncompletiondate = $dateEnd
                action_isresponse = $false
                validate_response = $false
                sendemail         = $false
            }
            $Null = New-HaloAction -Action $ActionUpdate
            Write-Host "Adding ticket entry $ActionUpdate"
        }
    }
    
    if ($Request.Body.resolvedAlert -eq "true") {
        Write-Host "Resolved Closing $ticketidHalo"
        if ($null -ne $ticketidHalo){
            $TicketID = $ticketidHalo
        
            $TicketUpdate = @{
                id        = $TicketID 
                status_id = 9
                agent_id  = 38
            }
            $null = Set-HaloTicket -Ticket $TicketUpdate

            $Actions = Get-HaloAction -TicketID $TicketID

            # Mass review logic
            foreach ($action in $actions) {
               $ReviewData = @{
                   ticket_id = $action.ticket_id
                   id = $action.id
                   actreviewed = "true"
                }
                Set-HaloAction -Action $ReviewData
            }

            $dateInvoice = (get-date)
            $invoice = @{ 
                client_id = $HaloClientDattoMatch
                invoice_date = $dateInvoice
                lines = @(@{entity_type = "labour";ticket_id = $TicketID})
            }

            $null = New-HaloInvoice -Invoice $invoice 
        }
        
    } else {
        # Check for alert consolidation before creating new tickets
        Write-Host "Checking if alert should be consolidated with existing ticket..."
        $wasConsolidated = Test-AlertConsolidation -HaloTicketCreate $HaloTicketCreate -AlertWebhook $AlertWebhook
        
        if ($wasConsolidated) {
            Write-Host "Alert was successfully consolidated with existing ticket. No new ticket created."
        } else {
            Write-Host "No consolidation performed. Processing alert normally..."
            
            # Handle Specific Ticket responses based on ticket subject type
            # Check if the alert message contains the specific disk usage alert for the C: drive
            if ($TicketSubject -like "*Alert: Disk Usage - C:*") {
                Handle-DiskUsageAlert -Request $Request -HaloTicketCreate $HaloTicketCreate -HaloClientDattoMatch $HaloClientDattoMatch
            } elseif ($TicketSubject -like "*Monitor Hyper-V Replication*") {
                Handle-HyperVReplicationAlert -HaloTicketCreate $HaloTicketCreate
            } elseif ($TicketSubject -like "*Alert: Patch Monitor - Failure whilst running Patch Policy*") {
                Handle-PatchMonitorAlert -AlertWebhook $AlertWebhook -HaloTicketCreate $HaloTicketCreate -tableName $tableName
                #Handle-DefaultAlert -HaloTicketCreate $HaloTicketCreate
            } elseif ($TicketSubject -like "*Alert: Event Log - Backup Exec*") {
                Handle-BackupExecAlert -HaloTicketCreate $HaloTicketCreate
            } elseif ($TicketSubject -like "*HOSTS Integrity Monitor*") {
                Handle-HostsAlert -HaloTicketCreate $HaloTicketCreate
            } else {
                Handle-DefaultAlert -HaloTicketCreate $HaloTicketCreate
            }
        }
    }
    #$HaloTicketCreate | Out-String | Write-Host #Enable for Debugging
} else {
        Write-Host "No alert found. This webhook shouldn't be triggered this way except when testing!!!!"
}