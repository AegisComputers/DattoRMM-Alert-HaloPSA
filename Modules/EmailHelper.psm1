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

# Exporting Module Members
Export-ModuleMember -Function Get-HaloUserEmail, Send-HaloEmailResponse, Send-HaloUserResponse, Send-PatchFailureUserEmail