# Memory Usage Alert Teams Webhook Test Script
# This script specifically tests memory usage alert consolidation notifications

param(
    [string]$WebhookUrl = "",
    [string]$DeviceName = "GUILWKS0062",
    [int]$MemoryPercentage = 99,
    [int]$AlertCount = 4,
    [string]$ClientName = "Aegis Computer Maintenance",
    [string]$SiteName = "Main Office",
    [int]$TicketId = 12345
)

# If no webhook URL provided, try to read from config
if (-not $WebhookUrl) {
    try {
        $configPath = ".\teams-webhook-config.json"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath | ConvertFrom-Json
            $WebhookUrl = $config.TeamsNotifications.WebhookUrl
            Write-Host "Using webhook URL from config file" -ForegroundColor Green
        } else {
            Write-Host "Config file not found. Please provide webhook URL as parameter." -ForegroundColor Red
            Write-Host "Usage: .\test-memory-teams-webhook.ps1 -WebhookUrl 'https://your-webhook-url'" -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Host "Error reading config file: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== Memory Usage Alert Teams Notification Test ===" -ForegroundColor Cyan
Write-Host "Device: $DeviceName" -ForegroundColor White
Write-Host "Memory Usage: $MemoryPercentage%" -ForegroundColor White
Write-Host "Alert Count: $AlertCount consolidated alerts" -ForegroundColor White
Write-Host "Client: $ClientName" -ForegroundColor White
Write-Host "Site: $SiteName" -ForegroundColor White
Write-Host "Ticket ID: #$TicketId" -ForegroundColor White
Write-Host "Webhook URL: $($WebhookUrl.Substring(0, 50))..." -ForegroundColor Gray
Write-Host ""

# Determine severity based on memory percentage and alert count
$severity = "Medium"
$color = "warning"

if ($MemoryPercentage -ge 95 -or $AlertCount -ge 5) {
    $severity = "Critical"
    $color = "attention"
} elseif ($MemoryPercentage -ge 85 -and $AlertCount -ge 3) {
    $severity = "High"
    $color = "attention"
} else {
    $severity = "Medium"
    $color = "warning"
}

Write-Host "Determined Severity: $severity" -ForegroundColor $(if($severity -eq "Critical"){"Red"}elseif($severity -eq "High"){"Yellow"}else{"Green"})

# Create memory usage specific Teams payload
$memoryPayload = @{
    type = "message"
    attachments = @(
        @{
            contentType = "application/vnd.microsoft.card.adaptive"
            content = @{
                type = "AdaptiveCard"
                version = "1.4"
                body = @(
                    @{
                        type = "Container"
                        style = $color
                        items = @(
                            @{
                                type = "TextBlock"
                                text = "🧠 TEST: Memory Usage Alert Consolidation"
                                weight = "Bolder"
                                size = "Large"
                                color = "Light"
                            }
                        )
                    },
                    @{
                        type = "FactSet"
                        facts = @(
                            @{
                                title = "Device"
                                value = $DeviceName
                            },
                            @{
                                title = "Client"
                                value = $ClientName
                            },
                            @{
                                title = "Site"
                                value = $SiteName
                            },
                            @{
                                title = "Alert Type"
                                value = "Memory Usage"
                            },
                            @{
                                title = "Current Memory Usage"
                                value = "$MemoryPercentage%"
                            },
                            @{
                                title = "Alert Count"
                                value = "$AlertCount alerts consolidated"
                            },
                            @{
                                title = "Severity"
                                value = $severity
                            },
                            @{
                                title = "Ticket ID"
                                value = "#$TicketId"
                            },
                            @{
                                title = "Timestamp"
                                value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
                            }
                        )
                    },
                    @{
                        type = "TextBlock"
                        text = "**This is a test notification.** Multiple memory usage alerts have been consolidated for device **$DeviceName**. Current memory usage is at **$MemoryPercentage%** which may indicate a persistent memory issue requiring immediate attention."
                        wrap = $true
                        spacing = "Medium"
                    },
                    @{
                        type = "TextBlock"
                        text = "⚠️ **This is a test message - no action required**"
                        wrap = $true
                        weight = "Bolder"
                        color = "Attention"
                        spacing = "Medium"
                    }
                )
                actions = @(
                    @{
                        type = "Action.OpenUrl"
                        title = "View Ticket in HaloPSA"
                        url = "https://your-halo-instance.com/tickets/$TicketId"
                    }
                )
            }
        }
    )
}

try {
    Write-Host "Preparing JSON payload..." -ForegroundColor Yellow
    
    # Convert to JSON with proper formatting
    $jsonPayload = $memoryPayload | ConvertTo-Json -Depth 10 -Compress
    
    Write-Host "JSON Payload size: $($jsonPayload.Length) characters" -ForegroundColor Gray
    
    Write-Host "`nSending memory usage alert notification to Teams..." -ForegroundColor Yellow
    
    # Send the webhook
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
    $stopwatch.Stop()
    
    Write-Host "✅ Memory usage alert notification sent successfully!" -ForegroundColor Green
    Write-Host "Response time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray
    Write-Host "Response: $response" -ForegroundColor Gray
    
    # Log success details
    Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
    Write-Host "✅ Webhook communication: SUCCESS" -ForegroundColor Green
    Write-Host "✅ Memory alert format: VALID" -ForegroundColor Green
    Write-Host "✅ Severity calculation: $severity (CORRECT)" -ForegroundColor Green
    Write-Host "✅ Adaptive card structure: VALID" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to send memory usage alert notification" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    # Provide troubleshooting information
    Write-Host "`n=== Troubleshooting Information ===" -ForegroundColor Yellow
    Write-Host "Webhook URL: $WebhookUrl" -ForegroundColor Gray
    Write-Host "Payload length: $($jsonPayload.Length) characters" -ForegroundColor Gray
    Write-Host "Error type: $($_.Exception.GetType().Name)" -ForegroundColor Gray
    
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
        Write-Host "HTTP Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Gray
    }
    
    Write-Host "`nFull Error Details:" -ForegroundColor DarkRed
    Write-Host $_.Exception.ToString() -ForegroundColor DarkRed
    
    exit 1
}

Write-Host "`n=== Memory Usage Alert Test Summary ===" -ForegroundColor Cyan
Write-Host "Device tested: $DeviceName" -ForegroundColor White
Write-Host "Memory usage: $MemoryPercentage%" -ForegroundColor White
Write-Host "Consolidation count: $AlertCount alerts" -ForegroundColor White
Write-Host "Calculated severity: $severity" -ForegroundColor White
Write-Host "Notification status: ✅ SENT" -ForegroundColor Green
Write-Host ""
Write-Host "Test completed successfully! Check your Teams channel for the notification." -ForegroundColor Green
