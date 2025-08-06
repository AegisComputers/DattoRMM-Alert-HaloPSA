
function Get-MapColour {
    param (
        $MapList,
        $Count
    )
    $Maximum = ($MapList | measure-object).count - 1
    $Index = [array]::indexof($MapList, "$count")
    $Sixth = $Maximum / 6

    if ($count -eq 0) {
        return "rgb(34,34,34)"
    } elseif ($Index -ge 0 -and $Index -le $Sixth) {
        return "rgb(226, 230, 190)"
    } elseif ($Index -gt $Sixth -and $Index -le $Sixth * 2) {
        return "rgb(237, 223, 133)"
    } elseif ($Index -gt $Sixth * 2 -and $Index -le $Sixth * 3) {
        return "rgb(238, 203, 117)"
    } elseif ($Index -gt $Sixth * 3 -and $Index -le $Sixth * 4) {
        return "rgb(227, 174, 105)"
    } elseif ($Index -gt $Sixth * 4 -and $Index -le $Sixth * 5) {
        return "rgb(205, 137, 92)"
    } elseif ($Index -gt $Sixth * 5 -and $Index -lt $Maximum) {
        return "rgb(172, 89, 77)"
    } else {
        return "rgb(130, 34, 59)"
    }    
}

function Get-HeatMap {
    param(
        $InputData,
        $XValues,
        $YValues
    )

    $BaseMap = [ordered]@{}
    foreach ($y in $YValues) {
        foreach ($x in $XValues) {
            $BaseMap.add("$($y)$($x)", 0)
        }
    }

    foreach ($DataToParse in $InputData) {
        $BaseMap["$($DataToParse)"] += 1
    }

    $MapValues = $BaseMap.values | Where-Object { $_ -ne 0 } | Group-Object
    $MapList = $MapValues.Name

    $HeaderRow = foreach ($x in $XValues) {
        "<th width=`"$(85/($XValues.count+1))%`" style=`"text-align:center`">$($x)</th>"
    }
    
    $HTMLRows = foreach ($y in $YValues) {
        $RowHTML = foreach ($x in $XValues) {
            '<td style="text-align:center; padding: 0; margin:0; border-collapse: collapse;"><svg height="25" width="100%" style="display:block;"><rect width="100%" height="100%" fill="' + $(Get-MapColour -MapList $MapList -Count $($BaseMap."$($y)$($x)")) + '" /></svg></td>'
        }       
        '<tr style="padding: 0; margin:0; border-spacing: 0px; border-collapse: collapse;"><td height=25px style="text-align:center; padding: 0; margin:0; border-collapse: collapse; line-height: 0px;">' + "$y</td>$RowHTML</tr>"
    }

    $Html = @"
    <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="padding: 0;margin:0;border-spacing: 0px;border-collapse: collapse;color: #ffffff;"><thead>
        <tr>
            <td width=15%></td>$HeaderRow
        </tr>
    </thead>
    $HTMLRows
    </table>
"@

    return $html
}

function Get-DecodedTable {
    param(
        $TableString,
        $UseValue
    )
    # "mscorsvw:48.7,system:1.3,msmpeng:0.6"
    $Parsed = $TableString -split "," | ForEach-Object {
        $Values = $_ -split ":"
        [pscustomobject]@{
            Application     = $Values[0]
            "Use $UseValue" = $Values[1]
        }
    }

    Return $Parsed

}

function Get-AlertDescription {
    param(
        $Alert
    )

    $AlertContext = $Alert.alertcontext

    switch ($AlertContext.'@class') {
        'perf_resource_usage_ctx' { $Result = "$($AlertContext.type) - $($AlertContext.percentage)" }
        'comp_script_ctx' { $Result = "$($AlertContext.Samples | convertto-html -as List -Fragment)" }
        'perf_mon_ctx' { $Result = "$($AlertContext.value)" }
        'online_offline_status_ctx' { $Result = "$($AlertContext.status)" }
        'eventlog_ctx' { $Result = "$($AlertContext.logName) - $($AlertContext.type) - $($AlertContext.code) - $($AlertContext.description)" }
        'perf_disk_usage_ctx' { $Result = "$($AlertContext.diskName) - $($AlertContext.freeSpace /1024/1024)GB free of $($AlertContext.totalVolume /1024/1024)GB" }
        'patch_ctx' { $Result = (Get-WindowsErrorMessage $AlertContext.result) }
        'srvc_status_ctx' { $Result = "$($AlertContext.serviceName) - $($AlertContext.status)" }
        'antivirus_ctx' { $Result = "$($AlertContext.productName) - $($AlertContext.status)" }
        'custom_snmp_ctx' { $Result = "$($AlertContext.displayName) - $($AlertContext.currentValue)" }
        'endpoint_security_threat_ctx' { $Result = "$($AlertContext.description)" }
        default { $Result = "Unknown Monitor Type" }
    }

    return $Result
}

function Get-AlertHaloType {
    param (
        $Alert,
        $AlertMessage
    )

    $AlertContext = $Alert.alertcontext

    switch ($AlertContext.'@class') {
        'perf_resource_usage_ctx' { $Result = "Resource Usage Alert - $($AlertContext.type)" }
        'comp_script_ctx' { $Result = "Component Alert - $((($AlertMessage -split '\[')[1] -split '\]')[0])" }
        'perf_mon_ctx' { $Result = "Performance Alert" }
        'online_offline_status_ctx' { $Result = "Offline Alert" }
        'eventlog_ctx' { $Result = "Event Log Alert - $($AlertContext.logName)-$($AlertContext.code)" }
        'perf_disk_usage_ctx' { $Result = "Disk Usage Alert - $($AlertContext.diskName)" }
        'patch_ctx' { $Result = "Patch Alert" }
        'srvc_status_ctx' { $Result = "Service Alert - $($AlertContext.serviceName)" }
        'antivirus_ctx' { $Result = "Anti Virus Alert $($AlertContext.productName)" }
        'custom_snmp_ctx' { $Result = "SNMP Alert - $($AlertContext.displayName)" }
        'endpoint_security_threat_ctx' { $Result = "$($AlertContext.description)" }
        default { $Result = "Unknown Monitor Type" }
    }
    
    return $Result
    
}


function Get-HTMLBody {
    param (
        $Sections,
        $NumberOfColumns
    )

    $HTMLHeader = @"
<!-- Header HTML Start -->
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
  <head>
    <!-- Compiled with Bootstrap Email version: 1.1.3 -->
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta http-equiv="x-ua-compatible" content="ie=edge">
    <meta name="x-apple-disable-message-reformatting">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="format-detection" content="telephone=no, date=no, address=no, email=no">
    <style type="text/css">
      body, table, td, th, tr {
        font-family: Helvetica, Arial, sans-serif !important;
        color: #ffffff !important;
      }
      .ExternalClass {
        width: 100%;
      }
      .ExternalClass, .ExternalClass p, .ExternalClass span, .ExternalClass font, .ExternalClass td, .ExternalClass div {
        line-height: 150%;
      }
      a {
        text-decoration: none;
      }
      * {
        color: #ffffff !important;
      }
      a[x-apple-data-detectors], u+#body a, #MessageViewBody a {
        color: #ffffff !important;
        text-decoration: none;
        font-size: inherit;
        font-family: inherit;
        font-weight: inherit;
        line-height: inherit;
      }
      img {
        -ms-interpolation-mode: bicubic;
      }
      table:not([class^=s-]) {
        font-family: Helvetica, Arial, sans-serif;
        mso-table-lspace: 0pt;
        mso-table-rspace: 0pt;
        border-spacing: 0px;
        border-collapse: collapse;
        color: #ffffff !important;
      }
      table:not([class^=s-]) td {
        border-spacing: 0px;
        border-collapse: collapse;
        color: #ffffff !important;
      }
      /* Added rule for white text color */
      table, table tbody tr, table tbody td {
          color: #ffffff !important;
      }
      @media screen and (max-width: 1800px) {
        .row-responsive.row {
          margin-right: 0 !important;
        }
        td.col-lg-4 {
          display: block;
          width: 100% !important;
          padding-left: 0 !important;
          padding-right: 0 !important;
        }
        .max-w-96, .max-w-96>tbody>tr>td {
          max-width: 1800px !important;
          width: 100% !important;
        }
        .w-full, .w-full>tbody>tr>td {
          width: 100% !important;
        }
        *[class*=s-lg-]>tbody>tr>td {
          font-size: 0 !important;
          line-height: 0 !important;
          height: 0 !important;
        }
        .s-10>tbody>tr>td {
          font-size: 40px !important;
          line-height: 40px !important;
          height: 40px !important;
        }
      }
    </style>
  </head>
  <body style="outline: 0; width: 100%; min-width: 100%; height: 100%; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; font-family: Helvetica, Arial, sans-serif; line-height: 24px; font-weight: normal; font-size: 16px; -moz-box-sizing: border-box; -webkit-box-sizing: border-box; box-sizing: border-box; color: #333333; margin: 0; padding: 0; border-width: 0;" bgcolor="#ffffff">
    <table class="body" valign="top" role="presentation" border="0" cellpadding="0" cellspacing="0" style="outline: 0; width: 100%; min-width: 100%; height: 100%; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; font-family: Helvetica, Arial, sans-serif; line-height: 24px; font-weight: normal; font-size: 16px; -moz-box-sizing: border-box; -webkit-box-sizing: border-box; box-sizing: border-box; color: #333333; margin: 0; padding: 0; border-width: 0;" bgcolor="#ffffff">
      <tbody style="width: 100%; max-width: 1800px; margin: 0 auto;">
        <tr>
          <td valign="top" style="line-height: 24px; font-size: 16px; margin: 0;" align="left">
            <table class="bg-black w-full" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%;" bgcolor="#333333" width="100%">
              <tbody style="width: 100%; max-width: 1800px; margin: 0 auto;">
                <tr>
                  <td style="line-height: 24px; font-size: 16px; width: 100%; margin: 0;" align="left" bgcolor="#333333" width="100%">
                    <table class="container" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 1800px;">
                      <tbody style="width: 100%; max-width: 1800px; margin: 0 auto;">
                        <tr>
                          <td align="center" style="line-height: 24px; font-size: 16px; margin: 0; padding: 0 16px;">
                            <table align="center" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 1800px; margin: 0 auto;">
                              <tbody style="width: 100%; max-width: 1800px; margin: 0 auto;">
                                <tr>
                                  <td style="line-height: 24px; font-size: 16px; margin: 0;" align="left">
                                  <!-- Header HTML End -->
"@

    $HTMLFooter = @"
<!-- Footer HTML Start -->
                                   </td>
                                </tr>
                              </tbody>
                            </table>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
          </td>
        </tr>
      </tbody>
    </table>
  </body>
</html>
<!-- Footer HTML End -->
"@


    $RowHeader = @"
<!-- Row Header HTML Start -->
<div class="row row-responsive" style="margin-right: -24px;">
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="table-layout: fixed; width: 100%;">
        <tbody>
            <tr>
            <!-- Row Header HTML End -->
"@

    $RowFooter = @"
<!-- Row Footer HTML Start -->
            </tr>
        </tbody>
    </table>
</div>
<!-- Row Footer HTML End -->
"@


    $CurrentColumn = 1
    $CalculatedWidth = 100 / $NumberOfColumns
    $SectionCount = 1

    $BlockHTML = foreach ($Section in $Sections) {

        [System.Collections.Generic.List[PSCustomObject]]$ReturnHtml = @()
        if ($currentColumn -eq 1) {
            $null = $ReturnHtml.add($RowHeader)
            Write-Host "New Row" 
        }

        Write-Host "$CurrentColumn"


        $Block = @"
    <!-- Block HTML Start -->
    <td class="col-lg-4"
        style="line-height: 24px; font-size: 16px; min-height: 1px; font-weight: normal; padding:24px; width: $CalculatedWidth%; margin: 0; background-color:#222222; border-right: 20px solid #333333; border-top: 20px solid #333333;"
        align="left" valign="top">
        <table width="100%"class="ax-center" role="presentation" align="center" border="0" cellpadding="0" cellspacing="0"
            style="margin: 0 auto;">
            <tbody>
                <tr>
                    <td style="line-height: 24px; font-size: 16px; margin: 0;" align="left">
                        <table class="ax-center" role="presentation" align="center" border="0" cellpadding="0"
                            cellspacing="0" style="margin: 0 auto;">
                            <tbody>
                                <tr>
                                    <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" height="100%"
                                        style="background-color:#222222;">
                                        <tr>
                                            <td
                                                style="padding: 10px 10px 0px 10px; font-family: sans-serif; font-size: 15px; line-height: 20px; color: #ffffff;">
                                                <h1
                                                    style="margin: 0 0 0px; font-size: 25px; line-height: 30px; color: #ffffff; font-weight: normal;">
                                                    $($Section.Heading)</h1>
                                            </td>
                                        </tr>
                                        <!-- Block Section HTML Start -->
                                        $($Section.HTML)
                                        <!-- Block Section HTML End -->
                                    </table>
                    </td>
                </tr>
            </tbody>
        </table>
    </td>
    <!-- Block HTML End -->
"@

        $null = $ReturnHtml.add($Block)

        if (($currentColumn -eq $NumberOfColumns) -or ($SectionCount -eq $Sections.count)) {
            $null = $ReturnHtml.add($RowFooter)
            Write-Host "New Footer"
            $currentColumn = 0
        }
        $currentColumn++
        $SectionCount++
        $ReturnHtml -join ''
    }
    $HTML = $HTMLHeader + ($BlockHTML) + $HTMLFooter

    return $HTML
}

Function Get-AlertEmailBody($AlertWebhook) {
    $DattoURL = $env:DattoURL
    $DattoKey = $env:DattoKey
    $DattoSecretKey = $env:DattoSecretKey
    $CPUUDF = $env:CPUUDF
    $RAMUDF = $env:RAMUDF
    $NumberOfColumns = $env:NumberOfColumns
    $AlertTroubleshooting = $AlertWebhook.troubleshootingNote
    $AlertDocumentationURL = $AlertWebhook.docURL
    $ShowDeviceDetails = $AlertWebhook.showDeviceDetails
    $ShowDeviceStatus = $AlertWebhook.showDeviceStatus
    $ShowAlertDetails = $AlertWebhook.showAlertDetails
    $AlertID = $AlertWebhook.alertUID
    $AlertMessage = $AlertWebhook.alertMessage
    $DattoPlatform = $AlertWebhook.platform

    $AlertTypesLookup = Get-AlertingConfig -Path "AlertTypeMapping" -DefaultValue @{
        perf_resource_usage_ctx      = 'Resource Monitor'
        comp_script_ctx              = 'Component Monitor'
        perf_mon_ctx                 = 'Performance Monitor'
        online_offline_status_ctx    = 'Offline'
        eventlog_ctx                 = 'Event Log'
        perf_disk_usage_ctx          = 'Disk Usage'
        patch_ctx                    = 'Patch Monitor'
        srvc_status_ctx              = 'Service Status'
        antivirus_ctx                = 'Antivirus'
        custom_snmp_ctx              = 'SNMP'
        endpoint_security_threat_ctx = "Endpoint Security"
    }

    $params = @{
        Url       = $DattoURL
        Key       = $DattoKey
        SecretKey = $DattoSecretKey
    }

    Set-DrmmApiParameters @params

    $Alert = Get-DrmmAlert -alertUid $AlertID

    if ($Alert) {
        [System.Collections.Generic.List[PSCustomObject]]$Sections = @()

        $Device = Get-DrmmDevice -deviceUid $Alert.alertSourceInfo.deviceUid
        $DeviceAudit = Get-DrmmAuditDevice -deviceUid $Alert.alertSourceInfo.deviceUid

        # Build the alert details section
        Get-DRMMAlertDetailsSection -Sections $Sections -Alert $Alert -Device $Device -AlertDocumentationURL $AlertDocumentationURL -AlertTroubleshooting $AlertTroubleshooting -DattoPlatform $DattoPlatform

        ## Build the device details section if enabled.
        if ($ShowDeviceDetails -eq $True) {
            Get-DRMMDeviceDetailsSection -Sections $Sections -Device $Device
        }
        # Build the device status section if enabled
        if ($ShowDeviceStatus -eq $true) {
            Get-DRMMDeviceStatusSection -Sections $Sections -Device $Device -DeviceAudit $DeviceAudit -CPUUDF $CPUUDF -RAMUDF $RAMUDF
        }
        if ($showAlertDetails -eq $true) {
            Get-DRMMAlertHistorySection -Sections $Sections -Alert $Alert -DattoPlatform $DattoPlatform
        }
        $TicketSubject = "Device: $($Device.hostname) raised Alert: $($AlertTypesLookup[$Alert.alertContext.'@class']) - $($AlertMessage)"

        $HTMLBody = Get-HTMLBody -Sections $Sections -NumberOfColumns $NumberOfColumns
    
        $Email = @{
            Subject = $TicketSubject
            Body    = $HTMLBody
            Alert = $Alert
        }

        Return $Email
    } else {
        Return $Null
    }
}

#AZStorageVars
$storageAccountName = "dattohaloalertsstgnirab"
$storageAccountKey = $env:strKey
$tableName = "DevicePatchAlerts"

# Function to create the storage context
function Get-StorageContext {
    return New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
}

# Function to get or create a table
function Get-StorageTable {
    param (
        [string]$tableName
    )
    try {
        $storageContext = Get-StorageContext
        $table = Get-AzStorageTable -Context $storageContext -Name $tableName -ErrorAction SilentlyContinue
        if (-not $table) {
            # Use try-catch to handle race conditions where table might be created by another process
            try {
                $table = New-AzStorageTable -Context $storageContext -Name $tableName
            } catch {
                # If creation fails (e.g., already exists), try to get it again
                Start-Sleep -Milliseconds 100  # Brief pause to allow other process to complete
                $table = Get-AzStorageTable -Context $storageContext -Name $tableName -ErrorAction SilentlyContinue
                if (-not $table) {
                    throw "Failed to create or retrieve storage table '$tableName': $($_.Exception.Message)"
                }
            }
        }
        return $table.CloudTable
    } catch {
        Write-Error "Storage table operation failed for '$tableName': $($_.Exception.Message)"
        throw
    }
}

# Function to insert or merge entity
function InsertOrMergeEntity {
    param (
        [Microsoft.Azure.Cosmos.Table.CloudTable]$table,
        [Microsoft.Azure.Cosmos.Table.DynamicTableEntity]$entity
    )
    $operation = [Microsoft.Azure.Cosmos.Table.TableOperation]::InsertOrMerge($entity)
    $result = $table.Execute($operation)
    return $result.Result
}

function GetEntity {
    param (
        $table,
        $partitionKey,
        $rowKey
    )
    try {
        $entity = Get-AzTableRow -RowKey $rowKey -Table $table -PartitionKey $partitionKey
        if ($null -ne $entity) {            
            return $entity
        } else {           
            return $null
        }
    } catch {
        return $null
    }
}

function Optimize-HtmlContentForTicket {
    param(
        [string]$OriginalHtml,
        [int]$MaxLength,
        [object]$Request,
        [string]$TicketSubject
    )
    
    # Ensure we never exceed the absolute limit - leave some buffer for safety
    $SafeMaxLength = [Math]::Min($MaxLength, 2900000)  # 2.9MB safe limit (100KB buffer below 3MB hard limit)
    
    # First try: compress whitespace and unnecessary formatting
    $CompressedHTMLBody = $OriginalHtml -replace '\s{2,}', ' ' -replace '>\s+<', '><' -replace '\r?\n\s*', ''
    
    if ($CompressedHTMLBody.Length -le $SafeMaxLength) {
        Write-Host "HTML optimized through compression: $($CompressedHTMLBody.Length) characters"
        return $CompressedHTMLBody
    }
    
    Write-Host "Creating streamlined version that preserves key alert sections..."
    
    # Extract key sections from the HTML - preserve critical data
    $AlertDetailsMatch = if ($OriginalHtml -match '(?s)<!-- Alert Detaills HTML Start -->.*?<!-- Alert Details HTML End -->') { 
        # Compress this section too
        $matches[0] -replace '\s{2,}', ' ' -replace '>\s+<', '><'
    } else { '' }
    
    $DeviceDetailsMatch = if ($OriginalHtml -match '(?s)<!-- Device Details HTML Start -->.*?<!-- Device Details HTML End -->') { 
        # Compress this section too
        $matches[0] -replace '\s{2,}', ' ' -replace '>\s+<', '><'
    } else { '' }
    
    # Extract device hostname and alert info for summary
    $DeviceHostname = if ($OriginalHtml -match 'Device:\s*([^<\s]+)') { $matches[1] } else { "Unknown Device" }
    $AlertPriority = if ($OriginalHtml -match '(\w+)\s+Alert\s+-\s+Site:') { $matches[1] } else { "Unknown Priority" }
    
    # Get the priority-specific styling to match original template
    $PriorityStyle = switch ($AlertPriority) {
        'Critical' { 'background-color:#EC422E; color:#1C3E4C' }
        'High' { 'background-color:#F68218; color:#1C3E4C' }
        'Moderate' { 'background-color:#F7C210; color:#1C3E4C' }
        'Low' { 'background-color:#2C81C8; color:#ffffff' }
        default { 'color:#ffffff;' }
    }
    
    # Create streamlined version using the exact same structure as original email template
    $StreamlinedHTMLBody = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style type="text/css">
body, table, td, th, tr {
  font-family: Helvetica, Arial, sans-serif !important;
  color: #ffffff !important;
}
* {
  color: #ffffff !important;
}
table:not([class^=s-]) {
  font-family: Helvetica, Arial, sans-serif;
  border-spacing: 0px;
  border-collapse: collapse;
  color: #ffffff !important;
}
table:not([class^=s-]) td {
  border-spacing: 0px;
  border-collapse: collapse;
  color: #ffffff !important;
}
table, table tbody tr, table tbody td {
  color: #ffffff !important;
}
</style>
</head>
<body style="margin: 0; padding: 0; font-family: Helvetica, Arial, sans-serif; background-color: #ffffff;">
<table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%;" bgcolor="#333333" width="100%">
<tbody>
<tr>
<td style="width: 100%; margin: 0; padding: 16px;" align="left" bgcolor="#333333" width="100%">
<table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 800px; margin: 0 auto;">
<tbody>
<tr>
<td style="margin: 0;" align="left">

<!-- Main content block matching original template structure -->
<table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color:#222222; margin-bottom: 20px;">
<tr>
<td style="padding: 20px; font-family: sans-serif; font-size: 15px; line-height: 20px; color: #ffffff;">
<h1 style="margin: 0 0 10px; font-size: 25px; line-height: 30px; font-weight: normal; $PriorityStyle">
$AlertPriority Alert - Site: $($Request.Body.dattoSiteDetails) - Device: $DeviceHostname
</h1>
<br />
<h3 style="color: #ffffff;">Alert Information:</h3>
<table style="width: 100%; border-collapse: collapse; color: #ffffff; margin: 10px 0;">
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Alert UID:</td><td style="padding: 5px 10px; color: #ffffff;">$($Request.Body.alertUID)</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Device:</td><td style="padding: 5px 10px; color: #ffffff;">$DeviceHostname</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Priority:</td><td style="padding: 5px 10px; color: #ffffff;">$AlertPriority</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Site:</td><td style="padding: 5px 10px; color: #ffffff;">$($Request.Body.dattoSiteDetails)</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Subject:</td><td style="padding: 5px 10px; color: #ffffff;">$TicketSubject</td></tr>
</table>
<br />
</td>
</tr>
</table>

$AlertDetailsMatch

<!-- Optimization notice block matching original style -->
<table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color:#222222; margin-top: 20px;">
<tr>
<td style="padding: 15px; font-family: sans-serif; font-size: 14px; line-height: 18px; color: #ffffff;">
<h3 style="margin-top: 0; color: #ffffff;">Content Optimization Notice</h3>
<p style="color: #ffffff; margin: 0 0 10px;">This alert has been optimized for transmission while preserving key data.</p>
<p style="color: #ffffff; margin: 0 0 10px;"><strong>Original size:</strong> $($OriginalHtml.Length) characters | <strong>Optimized size:</strong> [FINAL_SIZE] characters</p>
<p style="color: #ffffff; margin: 0;">For complete details including device status charts and alert history, please check the original alert in Datto RMM.</p>
</td>
</tr>
</table>

$DeviceDetailsMatch

</td>
</tr>
</tbody>
</table>
</td>
</tr>
</tbody>
</table>
</body>
</html>
"@
    
    # Check if streamlined version fits within limits
    if ($StreamlinedHTMLBody.Length -gt $SafeMaxLength) {
        Write-Host "Streamlined version still too large, creating minimal version..."
        
        # If alert details are too large, truncate them but preserve structure
        if ($AlertDetailsMatch.Length -gt 100000) {  # If alert details > 100KB
            $TruncatedAlertDetails = $AlertDetailsMatch.Substring(0, 50000) + "... [Alert details truncated]"
            $AlertDetailsMatch = $TruncatedAlertDetails
        }
        
        # Recreate streamlined version with potentially truncated content using exact original styling
        $StreamlinedHTMLBody = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style type="text/css">
body, table, td, th, tr { font-family: Helvetica, Arial, sans-serif !important; color: #ffffff !important; }
* { color: #ffffff !important; }
table:not([class^=s-]) { font-family: Helvetica, Arial, sans-serif; border-spacing: 0px; border-collapse: collapse; color: #ffffff !important; }
table:not([class^=s-]) td { border-spacing: 0px; border-collapse: collapse; color: #ffffff !important; }
table, table tbody tr, table tbody td { color: #ffffff !important; }
</style>
</head>
<body style="margin: 0; padding: 0; font-family: Helvetica, Arial, sans-serif; background-color: #ffffff;">
<table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%;" bgcolor="#333333" width="100%">
<tbody><tr><td style="width: 100%; margin: 0; padding: 16px;" align="left" bgcolor="#333333" width="100%">
<table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 800px; margin: 0 auto;">
<tbody><tr><td style="margin: 0;" align="left">

<table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color:#222222;">
<tr><td style="padding: 20px; font-family: sans-serif; font-size: 15px; line-height: 20px; color: #ffffff;">
<h1 style="margin: 0 0 10px; font-size: 25px; line-height: 30px; font-weight: normal; $PriorityStyle">
$AlertPriority Alert - Site: $($Request.Body.dattoSiteDetails) - Device: $DeviceHostname
</h1>
<br />
<h3 style="color: #ffffff;">Alert Information:</h3>
<table style="width: 100%; border-collapse: collapse; color: #ffffff; margin: 10px 0;">
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Alert UID:</td><td style="padding: 5px 10px; color: #ffffff;">$($Request.Body.alertUID)</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Device:</td><td style="padding: 5px 10px; color: #ffffff;">$DeviceHostname</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Priority:</td><td style="padding: 5px 10px; color: #ffffff;">$AlertPriority</td></tr>
<tr><td style="padding: 5px 0; font-weight: bold; color: #ffffff;">Site:</td><td style="padding: 5px 10px; color: #ffffff;">$($Request.Body.dattoSiteDetails)</td></tr>
</table>
<br />
</td></tr></table>

$AlertDetailsMatch

<table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color:#222222; margin-top: 15px;">
<tr><td style="padding: 15px; font-family: sans-serif; font-size: 14px; color: #ffffff;">
<p style="color: #ffffff; margin: 0;"><strong>Note:</strong> Content optimized from $($OriginalHtml.Length) characters. Check Datto RMM for complete details.</p>
</td></tr></table>

</td></tr></tbody></table></td></tr></tbody></table></body></html>
"@
        
        # Final safety check - if still too large, create ultra-minimal version
        if ($StreamlinedHTMLBody.Length -gt $SafeMaxLength) {
            Write-Host "Creating ultra-minimal version to ensure compliance with 3MB limit..."
            $MinimalHTMLBody = @"
<table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width: 100%;" bgcolor="#333333" width="100%">
<tbody><tr><td style="width: 100%; margin: 0; padding: 16px;" align="left" bgcolor="#333333" width="100%">
<table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color:#222222;">
<tr><td style="padding: 20px; font-family: sans-serif; font-size: 15px; line-height: 20px; color: #ffffff;">
<h1 style="margin: 0 0 10px; font-size: 25px; line-height: 30px; font-weight: normal; $PriorityStyle">
$AlertPriority Alert - $DeviceHostname
</h1>
<table style="width: 100%; border-collapse: collapse; margin: 15px 0; color: #ffffff;">
<tr style="background-color: #333333;"><td style="padding: 8px; font-weight: bold; color: #ffffff;">Alert UID:</td><td style="padding: 8px; color: #ffffff;">$($Request.Body.alertUID)</td></tr>
<tr><td style="padding: 8px; font-weight: bold; color: #ffffff;">Device:</td><td style="padding: 8px; color: #ffffff;">$DeviceHostname</td></tr>
<tr style="background-color: #333333;"><td style="padding: 8px; font-weight: bold; color: #ffffff;">Priority:</td><td style="padding: 8px; color: #ffffff;">$AlertPriority</td></tr>
<tr><td style="padding: 8px; font-weight: bold; color: #ffffff;">Site:</td><td style="padding: 8px; color: #ffffff;">$($Request.Body.dattoSiteDetails)</td></tr>
</table>
<p style="background-color: #333333; padding: 10px; border-left: 3px solid #ff9800; margin: 15px 0; color: #ffffff;">
<strong style="color: #ffffff;">Note:</strong> Alert content minimized from $($OriginalHtml.Length) characters to comply with size limits. Check Datto RMM for complete details.
</p>
</td></tr></table></td></tr></tbody></table>
"@
            return $MinimalHTMLBody
        }
        
        $FinalSize = $StreamlinedHTMLBody.Length
        return $StreamlinedHTMLBody -replace '\[FINAL_SIZE\]', $FinalSize
    } else {
        $FinalSize = $StreamlinedHTMLBody.Length
        return $StreamlinedHTMLBody -replace '\[FINAL_SIZE\]', $FinalSize
    }
}
