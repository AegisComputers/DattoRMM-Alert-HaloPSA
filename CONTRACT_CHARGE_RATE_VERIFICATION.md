# Contract & Charge Rate Implementation Verification

## Overview
This document verifies that charge rate 0 is correctly applied to all non-contract ticket actions throughout the entire ticket lifecycle.

---

## Ticket Lifecycle Coverage

### 1. ✅ TICKET CREATION (run.ps1)
**Location:** `Receive-Alert/run.ps1` lines ~204-250

**What happens:**
- Calls `Get-ContractTicketingDecision` to determine contract eligibility
- Sets ticket type: 8 (contract) or 9 (non-contract)
- Sets contract ID only if eligible, otherwise null

**Code:**
```powershell
$contractDecision = Get-ContractTicketingDecision -Contracts $Contracts -HaloSiteID $HaloSiteIDDatto -DattoDevice $DattoDevice -ClientID $HaloClientDattoMatch

$HaloTicketCreate = @{
    tickettype_id = $contractDecision.TicketTypeId    # 8 or 9
    contract_id   = $contractDecision.ContractId      # null if non-contract
    # ... other fields
}
```

**Charge Rate Logic:** ✅ Ticket type determines billing behavior throughout lifecycle

---

### 2. ✅ ADDING ENTRIES - Initial Resolution Action (run.ps1)
**Location:** `Receive-Alert/run.ps1` lines ~290-318

**What happens:**
- Creates "Resolved by Datto Automation" action when alert auto-resolves
- **Applies charge rate 0 for non-contract tickets**

**Code:**
```powershell
$ActionUpdate = @{
    ticket_id            = $Ticket.id
    outcome_id           = 23
    note                 = "Resolved by Datto Automation"
    actionarrivaldate    = Get-Date
    actioncompletiondate = Get-Date
    sendemail            = $false
}

# Apply charge rate 0 for non-contract tickets
if ($script:ContractDecision -and $script:ContractDecision.ChargeRate -eq 0) {
    $ActionUpdate.chargerate = 0
    Write-Host "Applied charge rate 0 (non-contract ticket)"
}

$null = New-HaloAction -Action $ActionUpdate
```

**Charge Rate Logic:** ✅ Explicitly sets chargerate = 0 for ticket type 9

---

### 3. ✅ ADDING ENTRIES - Security Alert Consolidation (TicketHandler.psm1)
**Location:** `Modules/TicketHandler.psm1` lines ~690-710

**What happens:**
- Adds consolidation notes when same alert repeats
- **Checks ticket type and applies charge rate 0 for non-contract**

**Code:**
```powershell
$actionToAdd = @{
    ticket_id            = $ExistingTicket.id
    actionid             = 23
    outcome              = "Remote"
    outcome_id           = 23
    note                 = $consolidationNote
    actionarrivaldate    = Get-Date
    actioncompletiondate = Get-Date
    action_isresponse    = $false
    validate_response    = $false
    sendemail            = $false
}

# Apply charge rate 0 for non-contract tickets (ticket type != 8)
if ($ExistingTicket.tickettype_id -and $ExistingTicket.tickettype_id -ne 8) {
    $actionToAdd.chargerate = 0
    Write-Host "Applied charge rate 0 for non-contract ticket (Type ID: $($ExistingTicket.tickettype_id))"
}

$actionResult = New-HaloAction -Action $actionToAdd
```

**Charge Rate Logic:** ✅ Checks `$ExistingTicket.tickettype_id -ne 8` and sets chargerate = 0

---

### 4. ✅ ADDING ENTRIES - Memory Usage Consolidation (TicketHandler.psm1)
**Location:** `Modules/TicketHandler.psm1` lines ~1090-1110

**What happens:**
- Adds consolidation notes for repeated memory usage alerts
- **Checks ticket type and applies charge rate 0 for non-contract**

**Code:**
```powershell
$action = @{
    ticket_id    = $ExistingTicket.id
    note         = $consolidationNote
    note_html    = "<p><strong>Memory Usage Alert Consolidation:</strong><br>$consolidationNote</p>"
    actiontypeid = 1  # Note action type
    sendemail    = $false
}

# Apply charge rate 0 for non-contract tickets (ticket type != 8)
if ($ExistingTicket.tickettype_id -and $ExistingTicket.tickettype_id -ne 8) {
    $action.chargerate = 0
    Write-Host "Applied charge rate 0 for non-contract ticket (Type ID: $($ExistingTicket.tickettype_id))"
}

$actionResult = New-HaloAction -Action $action
```

**Charge Rate Logic:** ✅ Checks `$ExistingTicket.tickettype_id -ne 8` and sets chargerate = 0

---

### 5. ✅ CLOSING TICKETS (run.ps1)
**Location:** `Receive-Alert/run.ps1` lines ~342-375

**What happens:**
- Sets ticket status to closed (status_id = 9)
- Marks all actions as reviewed (actreviewed = "true")
- **No new actions created during closure**

**Code:**
```powershell
# Close the ticket
$TicketUpdate = @{
    id        = $TicketID 
    status_id = 9
    agent_id  = 1
}
Set-HaloTicket -Ticket $TicketUpdate

# Mark all actions as reviewed
$Actions = Get-HaloAction -TicketID $TicketID -Count 10000
foreach ($action in $actions) {
   $ReviewData = @{
       ticket_id = $action.ticket_id
       id = $action.id
       actreviewed = "true"
    }
    Set-HaloAction -Action $ReviewData
}
```

**Charge Rate Logic:** ✅ No actions created = charge rates already set on existing actions

---

### 6. ✅ INVOICING (run.ps1)
**Location:** `Receive-Alert/run.ps1` lines ~378-388

**What happens:**
- Creates invoice from ticket ID
- **Invoice pulls from ticket actions that already have correct charge rates**

**Code:**
```powershell
$invoice = @{ 
    client_id = $HaloClientDattoMatch
    invoice_date = $dateInvoice
    lines = @(@{entity_type = "labour"; ticket_id = $TicketID})
}
$null = New-HaloInvoice -Invoice $invoice
```

**Charge Rate Logic:** ✅ Invoice uses actions with charge rates already applied (0 for non-contract)

---

## Contract Decision Logic (ContractHelper.psm1)

### Device Support Rules
**Location:** `Modules/ContractHelper.psm1`

| Scenario | Device Type | CFDevicesSupported | Result | Charge Rate |
|----------|-------------|-------------------|--------|-------------|
| MSA exists | Server | "All" or empty | Type 8 | Contract rate (default) |
| MSA exists | PC | "All" or empty | Type 8 | Contract rate (default) |
| MSA exists | Server | "Servers" | Type 8 | Contract rate (default) |
| MSA exists | PC | "Servers" | Type 9 | 0 (no charge) |
| MSA exists | Server | "PCs" | Type 9 | 0 (no charge) |
| MSA exists | PC | "PCs" | Type 8 | Contract rate (default) |
| No MSA | Any | N/A | Type 9 | 0 (no charge) |

### Key Features:
1. ✅ **Empty CFDevicesSupported defaults to "All"** - If MSA contract has no device support field set, it supports all devices
2. ✅ **-FullObjects flag required** - Must use `Get-HaloContract -ClientID X -FullObjects` to retrieve custom fields
3. ✅ **Device type detection** - Identifies Server vs PC from Datto device type or hostname patterns

---

## Email Actions (Not Currently Used)

**Location:** `Modules/EmailHelper.psm1` line 123

**Status:** ⚠️ Function `Send-HaloEmailResponse` exists but has no callers in the codebase

**If enabled in future:** Would need to accept ticket object as parameter and apply same charge rate logic:
```powershell
if ($Ticket.tickettype_id -and $Ticket.tickettype_id -ne 8) {
    $ActionUpdate.chargerate = 0
}
```

---

## Summary Checklist

### Ticket Creation
- [x] Contract decision logic implemented (`Get-ContractTicketingDecision`)
- [x] Ticket type set dynamically (8 vs 9)
- [x] Contract ID set only for eligible devices
- [x] -FullObjects flag used to retrieve contracts

### Adding Entries (Actions)
- [x] Initial resolution action has charge rate 0 for non-contract
- [x] Security alert consolidation has charge rate 0 for non-contract
- [x] Memory usage consolidation has charge rate 0 for non-contract
- [x] All action creation points check ticket type

### Closing & Invoicing
- [x] Ticket closure doesn't create new actions
- [x] Actions marked as reviewed use existing charge rates
- [x] Invoice creation pulls from actions with correct rates

### Contract Logic
- [x] Empty CFDevicesSupported defaults to "All"
- [x] Device type detection (Server/PC/Unknown)
- [x] MSA contract filtering (*M suffix)
- [x] InternalWork contract support

---

## Testing Recommendations

### Test Case 1: Contract Ticket with Consolidation
1. Device with active MSA contract supporting "All"
2. Create alert → Should be ticket type 8, contract ID set
3. Add consolidation note → Should NOT have charge rate set (uses contract default)
4. Close and invoice → Should bill according to MSA contract rates

### Test Case 2: Non-Contract Ticket with Consolidation
1. Device without MSA contract
2. Create alert → Should be ticket type 9, no contract ID
3. Add resolution action → Should have chargerate = 0
4. Add consolidation note → Should have chargerate = 0
5. Close and invoice → Should show $0 charges

### Test Case 3: Partial Contract Coverage
1. MSA exists with CFDevicesSupported = "Servers"
2. Server alert → Type 8, contract billing
3. PC alert → Type 9, chargerate = 0

### Test Case 4: Empty Device Support Field
1. MSA exists with no CFDevicesSupported field set
2. Any device alert → Should default to Type 8 (supports "All")

---

## Conclusion

✅ **All ticket lifecycle stages properly handle charge rates for non-contract tickets:**
- Ticket creation sets correct type (8 or 9)
- All action creation points apply charge rate 0 when ticket type != 8
- Closure and invoicing use existing action charge rates
- Empty CFDevicesSupported defaults to "All" (supports all devices)
- -FullObjects flag correctly used to retrieve custom fields

**No gaps identified.** The implementation is complete and consistent across the entire ticket lifecycle.
