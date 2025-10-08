# Teams Notification Error Handling Fix

## Issue
Alert consolidation was crashing when Teams notifications failed with a 400 Bad Request error.

### Error Details
```
ERROR_DETAILS: {
  "AlertUID":"00646d7c-7098-405e-87c6-aa8a3f83a899",
  "Timestamp":"2025-10-07 14:53:07",
  "Duration":28.5615264,
  "Command":"Test-AlertConsolidation",
  "Line":384,
  "Error":"Error in alert consolidation test: Error updating existing ticket: Failed to send Teams notification for An account failed to log on consolidation: Response status code does not indicate success: 400 (Bad Request)."
}
```

## Root Cause
Teams notification errors were **not being caught** in the calling functions, causing them to propagate up and crash the entire alert consolidation process. Even though the ticket update was successful, the whole operation failed because of an optional Teams notification.

## Solution Applied

### 1. Wrapped Teams Notification Calls in `Update-ExistingSecurityTicket`
**Location:** Line ~668 in `TicketHandler.psm1`

```powershell
# Before - Teams notification error would crash consolidation
if (($currentCount + 1) -ge $teamsNotificationThreshold) {
    Send-AlertConsolidationTeamsNotification ...
}

# After - Teams notification error is caught and logged
if (($currentCount + 1) -ge $teamsNotificationThreshold) {
    try {
        Send-AlertConsolidationTeamsNotification ...
    }
    catch {
        Write-Warning "Teams notification failed but continuing with ticket update: $($_.Exception.Message)"
        # Don't throw - just log and continue with the consolidation
    }
}
```

### 2. Wrapped Teams Notification Calls in `Update-ExistingMemoryUsageTicket`
**Location:** Line ~1050 in `TicketHandler.psm1`

```powershell
# Before - Teams notification error would crash consolidation
if ($occurrenceCount -ge $teamsNotificationThreshold) {
    Send-MemoryUsageTeamsNotification ...
}

# After - Teams notification error is caught and logged
if ($occurrenceCount -ge $teamsNotificationThreshold) {
    try {
        Send-MemoryUsageTeamsNotification ...
    }
    catch {
        Write-Warning "Teams notification failed but continuing with ticket update: $($_.Exception.Message)"
        # Don't throw - just log and continue with the consolidation
    }
}
```

### 3. Enhanced Error Handling in `Send-AlertConsolidationTeamsNotification`
**Location:** Line ~1319 in `TicketHandler.psm1`

Added graceful error handling that logs detailed HTTP status codes and continues without throwing:

```powershell
try {
    $null = Invoke-RestMethod -Uri $teamsWebhookUrl ...
    Write-Host "Teams notification sent successfully"
}
catch {
    # Log the error but don't throw - we don't want Teams notification failures to crash alert processing
    Write-Warning "Failed to send Teams notification, but continuing with alert processing"
    Write-Warning "Error: $($_.Exception.Message)"
    
    # Log HTTP status codes
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        Write-Host "HTTP Status Code: $statusCode"
        
        if ($statusCode -eq 400) {
            Write-Warning "Bad Request (400) - Check if Teams workflow is enabled and webhook URL is correct"
        }
    }
    
    # Don't throw - just log and continue
}
```

## What This Fixes

✅ **Alert consolidation continues even if Teams notification fails**
- Tickets are still updated with new alert information
- Consolidation notes are still added
- Alert processing completes successfully

✅ **Better error visibility**
- Clear warnings show Teams notification failures
- HTTP status codes are logged for troubleshooting
- Error messages explain common issues (disabled workflow, bad URL, etc.)

✅ **No more crashes from optional features**
- Teams notifications are truly optional now
- One failing subsystem doesn't break the entire alert flow

## Common Teams Notification Errors

### 400 Bad Request
- **Cause:** Teams workflow is disabled, or webhook URL is incorrect
- **Result:** Warning logged, alert consolidation continues
- **Action:** Enable the Power Automate workflow or check webhook URL

### 404 Not Found
- **Cause:** Webhook URL is invalid or expired
- **Result:** Warning logged, alert consolidation continues
- **Action:** Update webhook URL in `teams-webhook-config.json`

### 429 Too Many Requests
- **Cause:** Rate limit exceeded
- **Result:** Warning logged, alert consolidation continues
- **Action:** Reduce notification frequency or increase threshold

## Testing

To verify the fix works:

1. **Disable your Teams workflow** (or use an invalid webhook URL)
2. **Trigger an alert consolidation** (3+ occurrences of same alert type on same device)
3. **Check Azure Function logs:**

Expected output:
```
Testing consolidation for device 'DEVICE01' and alert type 'An account failed to log on'
Found existing ticket for consolidation: 12345
Teams notification failed but continuing with ticket update: Response status code does not indicate success: 400 (Bad Request).
Successfully updated ticket 12345 with new alert details.
Successfully consolidated alert into existing ticket 12345
```

✅ **The consolidation should succeed** even though Teams notification failed!

## Files Modified

- `Modules/TicketHandler.psm1`
  - Line ~668: Added try-catch around security alert Teams notification
  - Line ~1050: Added try-catch around memory usage Teams notification
  - Line ~1319-1345: Enhanced error handling in Teams notification function

## Configuration

No configuration changes needed. The existing `teams-webhook-config.json` settings continue to work:

```json
{
  "TeamsNotifications": {
    "WebhookUrl": "https://...",
    "EnableNotifications": true,
    "NotificationThresholds": {
      "MemoryUsage": {
        "MinOccurrenceCount": 3
      }
    }
  }
}
```

## Summary

Teams notifications are now **truly optional** and will never crash your alert processing. If the Teams webhook fails (disabled workflow, bad URL, rate limited, etc.), you'll get clear warning messages in the logs, but the core alert consolidation will continue to work perfectly.

---

**Date Fixed:** October 7, 2025  
**Issue Tracking:** Error in Test-AlertConsolidation at line 384
