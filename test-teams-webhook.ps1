# Teams Webhook Test Script
# This script demonstrates how to test the Teams notification functionality

param(
    [Parameter(Mandatory=$true)]
    [string]$WebhookUrl,
    [string]$DeviceName = "TEST-DEVICE-001",
    [string]$AlertType = "Security",
    [string]$AlertDetails = "Failed login attempts detected",
    [int]$AlertCount = 4
)

Write-Host "Testing Teams Webhook Notification..." -ForegroundColor Cyan
Write-Host "Webhook URL: $WebhookUrl" -ForegroundColor Gray
Write-Host "Device: $DeviceName" -ForegroundColor Gray
Write-Host "Alert Type: $AlertType" -ForegroundColor Gray
Write-Host "Alert Details: $AlertDetails" -ForegroundColor Gray
Write-Host "Alert Count: $AlertCount" -ForegroundColor Gray
Write-Host ""

# Determine icon and color based on alert type
$icon = "🚨"
$color = "warning"

switch ($AlertType.ToLower()) {
    "security" { $icon = "🔒"; $color = "attention" }
    "memory usage" { $icon = "🧠"; $color = "warning" }
    "disk usage" { $icon = "💾"; $color = "warning" }
    "event log" { $icon = "📋"; $color = "good" }
}

# Create test payload
$testPayload = @{
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
                                text = "$icon TEST: Alert Consolidation - $AlertType"
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
                                value = "TEST CLIENT"
                            },
                            @{
                                title = "Site"
                                value = "TEST SITE"
                            },
                            @{
                                title = "Alert Type"
                                value = $AlertType
                            },
                            @{
                                title = "Alert Details"
                                value = $AlertDetails
                            },
                            @{
                                title = "Alert Count"
                                value = "$AlertCount alerts consolidated"
                            },
                            @{
                                title = "Severity"
                                value = "TEST"
                            },
                            @{
                                title = "Ticket ID"
                                value = "#TEST-12345"
                            },
                            @{
                                title = "Timestamp"
                                value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
                            }
                        )
                    },
                    @{
                        type = "TextBlock"
                        text = "**This is a test notification.** Multiple **$AlertType** alerts have been consolidated for device **$DeviceName**. This may indicate a persistent issue requiring attention."
                        wrap = $true
                        spacing = "Medium"
                    },
                    @{
                        type = "TextBlock"
                        text = "⚠️ **This is a test message - no action required**"
                        wrap = $true
                        weight = "Bolder"
                        color = "Attention"
                    }
                )
                actions = @(
                    @{
                        type = "Action.OpenUrl"
                        title = "View Test Ticket"
                        url = "https://example.com/tickets/12345"
                    }
                )
            }
        }
    )
}

try {
    # Convert to JSON
    $jsonPayload = $testPayload | ConvertTo-Json -Depth 10 -Compress
    
    Write-Host "Sending test notification..." -ForegroundColor Yellow
    
    # Send the webhook
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
    
    Write-Host "✅ Test notification sent successfully!" -ForegroundColor Green
    Write-Host "Response: $response" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Failed to send test notification" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full Error: $($_.Exception.ToString())" -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "Test completed." -ForegroundColor Cyan
