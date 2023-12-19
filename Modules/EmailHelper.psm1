function GetUserEmail {
    param (
        $Username
    )
    #Get Email address based on provided username. 
    
}

function SendResponse {
    param (
        $EmailAddress,
        $EmailMessage,
        $TicketId
    )
    #Send the request through Halo to send an email. 
    $dateArrival = (get-date((get-date).AddMinutes(-1)))
    $dateEnd = (get-date) 
    
    $ActionUpdate = @{
        ticket_id               = $TicketId
        outcome                 = "Email User"
        outcome_id              = 16
        emailfrom               = "IT Support"
        replytoaddress          = "helpdesk@aegis-group.co.uk"
        emailto                 = $EmailAddress
        #emailsubject           = ""
        note                    = $EmailMessage
        actionarrivaldate       = $dateArrival
        actioncompletiondate    = $dateEnd
        action_isresponse       = $false
        validate_response       = $false
        sendemail               = $true
    }

    $Null = New-HaloAction -Action $ActionUpdate
}
