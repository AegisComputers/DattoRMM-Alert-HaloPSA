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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [int]$ClientId
    )

    try {
        $address = (Get-HaloUser -Search $Username -ClientID $ClientId).emailaddress

        if (-not $address) {
            Write-Error "No email address found for user $Username with client ID $ClientId"
            return $false
        } else { 
            return $address
        }
    } catch {
        Write-Error "Failed to retrieve email address: $_"
        return $false
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$EmailAddress,

        [Parameter(Mandatory)]
        [string]$EmailMessage,

        [Parameter(Mandatory)]
        [int]$TicketId
    )

    try {
        # Sends an email response via Halo.
        $dateArrival = (Get-Date).AddMinutes(-1)
        $dateEnd = Get-Date

        $ActionUpdate = @{
            ticket_id             = $TicketId
            outcome               = "Email User"
            outcome_id            = 16
            emailfrom             = "IT Support"
            replytoaddress        = "helpdesk@aegis-group.co.uk"
            emailto               = $EmailAddress
            note                  = $EmailMessage
            actionarrivaldate     = $dateArrival
            actioncompletiondate  = $dateEnd
            action_isresponse     = $false
            validate_response     = $false
            sendemail             = $true
        }

        New-HaloAction -Action $ActionUpdate

    } catch {
        Write-Error "Failed to send email: $_"
        return $false
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
function FindAndSendHaloResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [int]$ClientId,

        [Parameter(Mandatory)]
        [string]$EmailMessage,

        [Parameter(Mandatory)]
        [int]$TicketId
    )

    try {
        $EmailAddress = Get-HaloUserEmail -Username $Username -ClientId $ClientId

        if (-not $EmailAddress) {
            Write-Error "Email address not found for user $Username"
            return $false
        }

        $sendResult = Send-HaloEmailResponse -EmailAddress $EmailAddress -EmailMessage $EmailMessage -TicketId $TicketId

        if (-not $sendResult) {
            Write-Error "Failed to send email to $EmailAddress"
            return $false
        }

        return $true
    } catch {
        Write-Error "An error occurred: $_"
        return $false
    }
}

# Exporting Module Members
Export-ModuleMember -Function Get-HaloUserEmail, Send-HaloEmailResponse, FindAndSendHaloResponse