using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

Write-Host "Processing Webhook for Alert - $($Request.Body.alertUID) -"

$HaloClientID = $env:HaloClientID
$HaloClientSecret = $env:HaloClientSecret
$HaloURL = $env:HaloURL

$HaloTicketStatusID = $env:HaloTicketStatusID
$HaloCustomAlertTypeField = $env:HaloCustomAlertTypeField
$HaloTicketType = $env:HaloTicketType
$HaloReocurringStatus = $env:HaloReocurringStatus

#Custom Env Vars
$DattoAlertUIDField = $env:DattoAlertUIDField

# Set if the ticket will be marked as responded in Halo
$SetTicketResponded = $True

# Relates the tickets in Halo if the alerts arrive within x minutes for a device.
$RelatedAlertMinutes = 5

# Creates a child ticket in Halo off the main ticket if it reocurrs with the specified number of hours.
$ReoccurringTicketHours = 24

$HaloAlertHistoryDays = 90

$PriorityHaloMap = @{
    "Critical"    = "1"
    "High"        = "2"
    "Moderate"    = "3"
    "Low"         = "4"
    "Information" = "4"
}

$AlertWebhook = $Request.Body # | ConvertTo-Json -Depth 100

$Email = Get-AlertEmailBody -AlertWebhook $AlertWebhook

if ($Email) {
    $Alert = $Email.Alert

    Connect-HaloAPI -URL $HaloURL -ClientId $HaloClientID -ClientSecret $HaloClientSecret -Scopes "all"
    
    $HaloDeviceReport = @{
        name                    = "Datto RMM Improved Alerts PowerShell Function - Device Report"
        sql                     = "Select did, Dsite, DDattoID, DDattoAlternateId from device"
        description             = "This report is used to quickly obtain device mapping information for use with the improved Datto RMM Alerts Function"
        type                    = 0
        datasource_id           = 0
        canbeaccessedbyallusers = $false
    }

    $ParsedAlertType = Get-AlertHaloType -Alert $Alert -AlertMessage $AlertWebhook.alertMessage

    $HaloDevice = Invoke-HaloReport -Report $HaloDeviceReport -IncludeReport | where-object { $_.DDattoID -eq $Alert.alertSourceInfo.deviceUid }

    $HaloAlertsReportBase = @{
        name                    = "Datto RMM Improved Alerts PowerShell Function - Alerts Report"
        sql                     = "SELECT Faultid, Symptom, tstatusdesc, dateoccured, inventorynumber, FGFIAlertType, CFDattoAlertType, fxrefto as ParentID, fcreatedfromid as RelatedID FROM FAULTS inner join TSTATUS on Status = Tstatus Where CFDattoAlertType is not null and fdeleted <> 1"
        description             = "This report is used to quickly obtain alert information for use with the improved Datto RMM Alerts Function"
        type                    = 0
        datasource_id           = 0
        canbeaccessedbyallusers = $false
    }

    $HaloAlertsReport = Invoke-HaloReport -Report $HaloAlertsReportBase

    $AlertReportFilter = @{
        id                       = $HaloAlertsReport.id
        filters                  = @(
            @{
                fieldname      = 'inventorynumber'
                stringruletype = 2
                stringruletext = "$($HaloDevice.did)"
            }
        )
        _loadreportonly          = $true
        reportingperiodstartdate = get-date(((Get-date).ToUniversalTime()).adddays(-$HaloAlertHistoryDays)) -UFormat '+%Y-%m-%dT%H:%M:%SZ'
        reportingperiodenddate   = get-date((Get-date -Hour 23 -Minute 59 -second 59).ToUniversalTime()) -UFormat '+%Y-%m-%dT%H:%M:%SZ'
        reportingperioddatefield = "dateoccured"
        reportingperiod          = "7"
    }

    $ReportResults = (Set-HaloReport -Report $AlertReportFilter).report.rows

    $ReoccuringHistory = $ReportResults | where-object { $_.CFDattoAlertType -eq $ParsedAlertType } 
    
    $ReoccuringAlerts = $ReoccuringHistory | where-object { $_.dateoccured -gt ((Get-Date).addhours(-$ReoccurringTicketHours)) }

    $RelatedAlerts = $ReportResults | where-object { $_.dateoccured -gt ((Get-Date).addminutes(-$RelatedAlertMinutes)).ToUniversalTime() -and $_.CFDattoAlertType -ne $ParsedAlertType }
        
    $TicketSubject = $Email.Subject

    $HTMLBody = $Email.Body

    $HaloPriority = $PriorityHaloMap."$($Alert.Priority)"

    $HaloTicketCreate = @{
        summary          = $TicketSubject
        tickettype_id    = 8
        details_html     = $HtmlBody
        DattoAlertState = 0
        site_id          = 286
        assets           = @(@{id = $HaloDevice.did })
        priority_id      = $HaloPriority
        status_id        = $HaloTicketStatusID
        category_1       = "Datto Alert"
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


    # Handle reoccurring alerts
    if ($ReoccuringAlerts) {        
        $ReoccuringAlertParent = $ReoccuringAlerts | Sort-Object FaultID | Select-Object -First 1
                
        if ($ReoccuringAlertParent.ParentID) {
            $ParentID = $ReoccuringAlertParent.ParentID
        } else {
            $ParentID = $ReoccuringAlertParent.FaultID
        }
        
        $RecurringUpdate = @{
            id        = $ParentID
            status_id = $HaloReocurringStatus   
        }

        $null = Set-HaloTicket -Ticket $RecurringUpdate

        $HaloTicketCreate.add('parent_id', $ParentID)
        
    } elseif ($RelatedAlerts) {
        $RelatedAlertsParent = $RelatedAlerts | Sort-Object FaultID | Select-Object -First 1

        if ($RelatedAlertsParent.RelatedID -ne 0) {
            $CreatedFromID = $RelatedAlertsParent.RelatedID
        } else {
            $CreatedFromID = $RelatedAlertsParent.FaultID
        }
        
        $HaloTicketCreate.add('createdfrom_id', $CreatedFromID)

    } 

    # Your command to get tickets
    $TicketidGet = Get-HaloTicket -Category1 145 -OpenOnly -FullObjects

    # The UID you are looking for
    $targetUID = "d001df5e-ed49-4077-9479-fa7e3d08b121"

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
            
            $ActionUpdate = @{
                ticket_id         = $ticketidHalo
                actionid          = 23
                outcome           = "Remote"
                note              = "Resolved by Datto Automation"
                #actionarrivaldate = (get-date((get-date).AddMinutes(-30)))
                #actioncompletiondate = (get-date) 
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

        $TicketID = $ticketidHalo
        
        $TicketUpdate = @{
            id        = $TicketID 
            status_id = 28
            agent_id  = 38
        }
        $null = Set-HaloTicket -Ticket $TicketUpdate
    } else {
        Write-Host "Creating Ticket"
        $Ticket = New-HaloTicket -Ticket $HaloTicketCreate
    }

    $HaloTicketCreate | Out-String | Write-Host

} else {
        Write-Host "No alert found"
}



# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = ''
    })
