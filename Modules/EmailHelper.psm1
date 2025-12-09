# EmailHelper Module - Email and user response management for HaloPSA integration
Set-StrictMode -Version Latest

<#
.SYNOPSIS
Retrieves the email address for a specified Halo user.

.DESCRIPTION
This function fetches the email address associated with a given Halo user using their username and client ID. 
If no email address is found, it returns false.

.PARAMETER Username
The username of the Halo user.

.PARAMETER ClientId
The client ID associated with the Halo user.

.EXAMPLE
Get-HaloUserEmail -Username "jdoe" -ClientId 12345
Returns the email address of the Halo user with username 'jdoe' and client ID '12345'.
#>
function Get-HaloUserEmail {
    # Define the function with the name 'Get-HaloUserEmail'
    # It is declared with [CmdletBinding()] to enable advanced cmdlet functionality
    [CmdletBinding()]
    param (
        # Define the first parameter 'Username' as mandatory and of type string
        [Parameter(Mandatory)]
        [string]$Username,

        # Define the second parameter 'ClientId' as mandatory and of type integer
        [Parameter(Mandatory)]
        [int]$ClientId
    )

    try {
        # Try to execute the following block of code
        Write-Host "Looking up user '$Username' for client ID $ClientId"
        
        # Retrieve user(s) by calling the Get-HaloUser cmdlet with the provided Username and ClientId
        $users = @(Get-HaloUser -Search $Username -ClientID $ClientId)
        
        if (-not $users -or $users.Count -eq 0) {
            Write-Warning "No users found matching '$Username' with client ID $ClientId"
            return $false
        }
        
        # Try to find best match - prioritize exact matches on various fields
        $matchedUser = $null
        
        # First, try exact username match (case-insensitive)
        $matchedUser = $users | Where-Object { $_.name -eq $Username } | Select-Object -First 1
        
        # If no exact match, try matching network login (common for AD usernames)
        if (-not $matchedUser) {
            $matchedUser = $users | Where-Object { $_.networklogin -like "*$Username*" } | Select-Object -First 1
        }
        
        # If still no match, try matching email address prefix (e.g., jordan.kippax from jordan.kippax@domain.com)
        if (-not $matchedUser) {
            $matchedUser = $users | Where-Object { $_.emailaddress -like "$Username@*" } | Select-Object -First 1
        }
        
        # If still no match, try matching AD object
        if (-not $matchedUser) {
            $matchedUser = $users | Where-Object { $_.adobject -like "*$Username*" } | Select-Object -First 1
        }
        
        # If still no match, just take the first result (search found something)
        if (-not $matchedUser) {
            Write-Host "No exact match found, using first search result"
            $matchedUser = $users[0]
        }
        
        $address = $matchedUser.emailaddress
        
        if (-not $address) {
            # If $address is null or empty, write an error message indicating no email address was found
            Write-Warning "User found but no email address set for user '$($matchedUser.name)' (ID: $($matchedUser.id))"
            return $false
        }
        else { 
            # If an email address was found, return it
            Write-Host "Found email address '$address' for user '$($matchedUser.name)'"
            return $address
        }
    }
    catch {
        # If any exception occurs, catch it and handle it here
        # Write an error message with the exception details
        Write-Error "Failed to retrieve email address: $_"
        return $false
        # Return $false to indicate failure
    }
}

<#
.SYNOPSIS
Sends an email response via Halo for a specific ticket.

.DESCRIPTION
This function sends an email response through the Halo system. It requires the recipient's email address, 
a message to be sent, and the ticket ID related to the Halo action.

.PARAMETER EmailAddress
The email address to which the message will be sent.

.PARAMETER EmailMessage
The message content to be sent in the email.

.PARAMETER TicketId
The ticket ID associated with the Halo action.

.EXAMPLE
Send-HaloEmailResponse -EmailAddress "user@example.com" -EmailMessage "Your issue has been resolved." -TicketId 1001
Sends an email to 'user@example.com' with the message "Your issue has been resolved." for ticket ID 1001.
#>
function Send-HaloEmailResponse {
    # Define the function with the name 'Send-HaloEmailResponse'
    # It is declared with [CmdletBinding()] to enable advanced cmdlet functionality
    [CmdletBinding()]
    param (
        # Define the first parameter 'EmailAddress' as mandatory and of type string
        [Parameter(Mandatory)]
        [string]$EmailAddress,

        # Define the second parameter 'EmailMessage' as mandatory and of type string
        [Parameter(Mandatory)]
        [string]$EmailMessage,

        # Define the third parameter 'TicketId' as mandatory and of type integer
        [Parameter(Mandatory)]
        [int]$TicketId
    )

    try {
        # Try to execute the following block of code

        # Set the action arrival time to one minute before the current time
        $dateArrival = (Get-Date).AddMinutes(-1)
        
        # Set the action completion time to the current time
        $dateEnd = Get-Date

        # Create a hashtable containing the details of the action to be performed
        $ActionUpdate = @{
            ticket_id            = $TicketId                 # ID of the ticket to update
            outcome              = "Email User"              # Description of the outcome
            outcome_id           = 72                        # Presumed identifier for the "Email User" outcome
            new_status           = 20                        # end status of ticket
            actionarrivaldate    = $dateArrival             # Action arrival time
            actioncompletiondate = $dateEnd                 # Action completion time
            emailto              = $EmailAddress             # Recipient's email address
            note_html            = $EmailMessage             # The message body to be sent
            timetaken            = 0.016314166666666668      # 1 minute of time
            sendemail            = $true                     # Flag to actually send the email
        }

        # Execute the action by calling the New-HaloAction cmdlet with the constructed action hashtable
        New-HaloAction -Action $ActionUpdate

    }
    catch {
        # If any exception occurs, catch it and handle it here
        # Write an error message with the exception details
        Write-Error "Failed to send email: $_"
        return $false
        # Return $false to indicate failure
    }
}

<#
.SYNOPSIS
Sends an email response via Halo for a specific ticket.

.DESCRIPTION
This function sends an email response through the Halo system. It requires the recipient's email address, 
a message to be sent, and the ticket ID related to the Halo action.

.PARAMETER EmailAddress
The email address to which the message will be sent.

.PARAMETER EmailMessage
The message content to be sent in the email.

.PARAMETER TicketId
The ticket ID associated with the Halo action.

.EXAMPLE
Send-HaloEmailResponse -EmailAddress "user@example.com" -EmailMessage "Your issue has been resolved." -TicketId 1001
Sends an email to 'user@example.com' with the message "Your issue has been resolved." for ticket ID 1001.
#>
function Send-HaloUserResponse {
    # Define the function with the name 'Send-HaloUserResponse'
    # It is declared with [CmdletBinding()] to enable advanced cmdlet functionality
    [CmdletBinding()]
    param (
        # Define the first parameter 'Username' as mandatory and of type string
        [Parameter(Mandatory)]
        [string]$Username,

        # Define the second parameter 'ClientId' as mandatory and of type integer
        [Parameter(Mandatory)]
        [int]$ClientId,

        # Define the third parameter 'EmailMessage' as mandatory and of type string
        [Parameter(Mandatory)]
        [string]$EmailMessage,

        # Define the fourth parameter 'TicketId' as mandatory and of type integer
        [Parameter(Mandatory)]
        [int]$TicketId
    )

    try {
        # Try to execute the following block of code

        # Call the Get-HaloUserEmail function to retrieve the email address for the specified Username and ClientId
        $EmailAddress = Get-HaloUserEmail -Username $Username -ClientId $ClientId

        if (-not $EmailAddress) {
            # If the email address is not found, write an error message and return $false
            Write-Error "Email address not found for user $Username"
            return $false
        }

        # Call the Send-HaloEmailResponse function to send the email using the retrieved email address, message, and ticket ID
        $sendResult = Send-HaloEmailResponse -EmailAddress $EmailAddress -EmailMessage $EmailMessage -TicketId $TicketId

        if (-not $sendResult) {
            # If sending the email fails, write an error message and return $false
            Write-Error "Failed to send email to $EmailAddress"
            return $false
        }

        # If everything succeeds, return $true to indicate success
        return $true
    }
    catch {
        # If any exception occurs, catch it and handle it here
        # Write an error message with the exception details
        Write-Error "An error occurred: $_"
        return $false
        # Return $false to indicate failure
    }
}

<#
.SYNOPSIS
Sends a patch failure notification email to the primary user of a device.

.DESCRIPTION
This function sends an instructional email to the device's primary user when Windows Updates fail repeatedly.
It retrieves the user information from the Halo asset, gets their email address, and sends detailed
instructions on how to manually run Windows Updates.

.PARAMETER HaloDevice
The Halo device object containing device and user information.

.PARAMETER ClientId
The client ID associated with the device.

.PARAMETER TicketId
The ticket ID associated with the patch failure alert.

.EXAMPLE
Send-PatchFailureUserEmail -HaloDevice $HaloDevice -ClientId 14 -TicketId 12345
Sends patch failure instructions to the primary user of the device.
#>
function Send-PatchFailureUserEmail {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$HaloDevice,

        [Parameter(Mandatory)]
        [int]$ClientId,

        [Parameter(Mandatory)]
        [int]$TicketId
    )

    try {
        # Check if user email notifications are enabled
        $emailEnabled = Get-AlertingConfig -Path "CustomerNotifications.PatchFailure.SendEmailToUser" -DefaultValue $false
        
        if (-not $emailEnabled) {
            Write-Host "Patch failure user email notifications are disabled in configuration"
            return $false
        }

        # Get the primary user from the Halo device
        if (-not $HaloDevice -or -not $HaloDevice.user_name) {
            Write-Warning "No primary user found for device. Cannot send patch failure email."
            return $false
        }

        $username = $HaloDevice.user_name
        Write-Host "Attempting to send patch failure email to user: $username"

        # Get the email template from configuration
        $emailMessage = Get-AlertingConfig -Path "CustomerNotifications.PatchFailure.EmailTemplate"
        
        if (-not $emailMessage) {
            Write-Warning "No email template configured for patch failures"
            return $false
        }

        # Call the Send-HaloUserResponse function to send the email
        $sendResult = Send-HaloUserResponse -Username $username -ClientId $ClientId -EmailMessage $emailMessage -TicketId $TicketId

        if ($sendResult) {
            Write-Host "Successfully sent patch failure email to $username"
            return $true
        }
        else {
            Write-Warning "Failed to send patch failure email to $username"
            return $false
        }
    }
    catch {
        Write-Error "Error sending patch failure user email: $_"
        return $false
    }
}

<#
.SYNOPSIS
Sends an alert directly to a customer email address and creates a zero-charge ticket in Halo.

.DESCRIPTION
This function is used when alerts should be forwarded to customers instead of being handled
internally. It sends a customer-friendly email and creates a closed ticket in Halo with 0 charge
for record-keeping purposes.

.PARAMETER CustomerEmail
The email address to send the alert to.

.PARAMETER EmailSubject
The subject line for the customer email.

.PARAMETER EmailBody
The HTML body content for the customer email.

.PARAMETER HaloTicketCreate
The Halo ticket creation hashtable (used to create the zero-charge tracking ticket).

.PARAMETER AlertUID
The Datto alert UID for tracking purposes.

.PARAMETER CustomerName
The customer/client name for logging.

.RETURNS
Hashtable with Success (bool), TicketId (int or null), and Message (string)

.EXAMPLE
$result = Send-AlertToCustomer -CustomerEmail "alerts@acme.com" -EmailSubject "Disk Space Alert" -EmailBody $body -HaloTicketCreate $ticketData -AlertUID "12345" -CustomerName "Acme Corp"
#>
function Send-AlertToCustomer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$CustomerEmail,

        [Parameter(Mandatory)]
        [string]$EmailSubject,

        [Parameter(Mandatory)]
        [string]$EmailBody,

        [Parameter(Mandatory)]
        [hashtable]$HaloTicketCreate,

        [Parameter(Mandatory)]
        [string]$AlertUID,

        [Parameter(Mandatory)]
        [string]$CustomerName
    )

    try {
        Write-Host "=== Routing Alert to Customer: $CustomerName ==="
        Write-Host "Customer Email: $CustomerEmail"
        Write-Host "Alert UID: $AlertUID"

        # Step 1: Create a tracking ticket in Halo (closed with 0 charge)
        # Modify the ticket to indicate it was forwarded to customer
        $trackingTicket = $HaloTicketCreate.Clone()
        $trackingTicket.summary = "[Forwarded to Customer] $($trackingTicket.summary)"
        $trackingTicket.details_html = @"
<p><strong>This alert was forwarded directly to the customer.</strong></p>
<p><strong>Customer Email:</strong> $CustomerEmail</p>
<p><strong>Alert UID:</strong> $AlertUID</p>
<hr>
$EmailBody
"@
        
        # Set ticket to closed status with 0 charge
        $trackingTicket.status_id = 9  # Closed
        $trackingTicket.ticket_type_id = Get-AlertingConfig -Path "TicketDefaults.NonContractTicketTypeId" -DefaultValue 9
        
        # Create the tracking ticket
        Write-Host "Creating tracking ticket in Halo (closed, 0 charge)..."
        $createdTicket = New-HaloTicket -Ticket $trackingTicket
        
        if (-not $createdTicket -or -not $createdTicket.id) {
            Write-Warning "Failed to create tracking ticket in Halo"
            $ticketId = $null
        }
        else {
            $ticketId = $createdTicket.id
            Write-Host "✓ Created tracking ticket ID: $ticketId"
            
            # Add an action with 0 charge to document the email was sent
            try {
                $dateArrival = (Get-Date).AddMinutes(-1)
                $dateEnd = Get-Date
                
                $actionData = @{
                    ticket_id            = $ticketId
                    outcome              = "Email Customer"
                    outcome_id           = 72
                    note_html            = "<p>Alert forwarded to customer at: <strong>$CustomerEmail</strong></p><p>Customer routing rule matched for this alert type.</p>"
                    actionarrivaldate    = $dateArrival
                    actioncompletiondate = $dateEnd
                    timetaken            = 0.016314166666666668  # 1 minute
                    chargerate           = 0  # Zero charge
                    sendemail            = $false
                    emailto              = $CustomerEmail
                }
                
                $null = New-HaloAction -Action $actionData
                Write-Host "✓ Added zero-charge action to tracking ticket"
            }
            catch {
                Write-Warning "Failed to add action to tracking ticket: $($_.Exception.Message)"
            }
        }

        # Step 2: Send the email directly to the customer
        Write-Host "Sending alert email to customer..."
        
        try {
            # Use Halo's email system if we have a ticket, otherwise would need SendGrid/SMTP
            if ($ticketId) {
                # Send via Halo action (already done above with sendemail flag)
                # Update the action to actually send the email
                $emailAction = @{
                    ticket_id    = $ticketId
                    outcome      = "Email Customer"
                    outcome_id   = 72
                    note_html    = $EmailBody
                    emailto      = $CustomerEmail
                    emailsubject = $EmailSubject
                    sendemail    = $true
                }
                
                $null = New-HaloAction -Action $emailAction
                Write-Host "✓ Email sent to customer via Halo"
            }
            else {
                Write-Warning "No ticket ID available - email not sent (would require direct SMTP/SendGrid configuration)"
            }
        }
        catch {
            Write-Warning "Error sending email to customer: $($_.Exception.Message)"
            # Don't fail the entire operation - ticket was created
        }

        # Return success result
        $result = @{
            Success  = $true
            TicketId = $ticketId
            Message  = "Alert successfully routed to customer $CustomerName at $CustomerEmail"
        }
        
        Write-Host "✓ Alert routing complete"
        return $result
    }
    catch {
        Write-Error "Error routing alert to customer: $($_.Exception.Message)"
        
        $result = @{
            Success  = $false
            TicketId = $null
            Message  = "Failed to route alert to customer: $($_.Exception.Message)"
        }
        
        return $result
    }
}

# Exporting Module Members
Export-ModuleMember -Function Get-HaloUserEmail, Send-HaloEmailResponse, Send-HaloUserResponse, Send-PatchFailureUserEmail, Send-AlertToCustomer