# Documents the current CPU and Memory usage percent along with the top 10 applications of each.
# Will use UDF 29 and 30 by default.
# Author: Luke Whitelock / mspp.io

param ([string]$Customfield1 = "Custom29",
    [string]$Customfield2 = "Custom30"
)

function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 
function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

if ([Environment]::GetEnvironmentVariable("Customfield1", "Process")) {
    $Customfield1 = [Environment]::GetEnvironmentVariable("Customfield1", "Process")
}
if ([Environment]::GetEnvironmentVariable("Customfield2", "Process")) {
    $Customfield2 = [Environment]::GetEnvironmentVariable("Customfield2", "Process")
}

try {

    $CPUResults = (Get-Counter '\Process(*)\% Processor Time' -SampleInterval 5 -ErrorAction Ignore).CounterSamples | Where-Object { ($_.InstanceName -eq '_total') -Or ($_.InstanceName -eq 'idle') -Or ($_.CookedValue -ge 0.5) } |  Select-Object -Property InstanceName, CookedValue | Sort-Object -Descending -Property CookedValue

    $Total = ($CPUResults | Where-Object { $_.instancename -eq '_total' }).cookedvalue
    $Idle = ($CPUResults | Where-Object { $_.instancename -eq 'idle' }).cookedvalue
    $CPUUse = [math]::round((($Total - $Idle) / $Total) * 100, 2)

    $CPUParsed = $CPUResults | Where-Object { $_.instancename -ne '_total' -and $_.instancename -ne 'idle' } | Select-Object @{n = 'Name'; e = { $_.InstanceName } }, @{n = 'Use'; e = { [math]::round(($_.CookedValue / $Total) * 100, 1) } } | where-object { $_.use -gt 0 }
    $CPUCompressed = ($CPUParsed | Select-Object -first 10 | ForEach-Object {
            "$($_.Name):$($_.Use)"
        }) -join ','

    $MemoryResults = Get-Process | Group-Object -Property ProcessName | Select-Object Name, @{n = 'Mem (GB)'; e = { '{0:N5}' -f (($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1GB) } } | Sort-Object -Property { [float]$_.'Mem (GB)' } -Desc | Where-Object { $_.'Mem (GB)' -ge 0.1 } | Select-Object -first 10
    $MemCompressed = ($MemoryResults | ForEach-Object {
            "$($_.Name):$([math]::round($_.'Mem (GB)',1))"
        }) -join ','

    $MemUse = Get-CIMInstance win32_operatingsystem | Foreach-object { "{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) * 100) / $_.TotalVisibleMemorySize) }

    $CPUDetails = @{
        T = $CPUUse
        D = $CPUCompressed
    } | ConvertTo-Json -Compress | Out-String

    $MEMDetails = @{
        T = $MemUse
        D = $MemCompressed
    } | ConvertTo-Json -Compress | Out-String


    Set-ItemProperty -Path HKLM:\SOFTWARE\CentraStage -Name $Customfield1  -Value $CPUDetails -Type String
    Set-ItemProperty -Path HKLM:\SOFTWARE\CentraStage -Name $Customfield2  -Value $MEMDetails -Type String

    write-DRRMAlert 'Success'

    exit 0
} catch {
    write-DRRMAlert "Documenting Failed"
    write-DRMMDiag $_
    exit 1
}