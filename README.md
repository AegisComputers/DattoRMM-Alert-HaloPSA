# DattoRMM-Alerts-Halo
Takes Datto RMM Alert Webhooks and sends them to Halo PSA

Heavily updated from https://github.com/lwhitelock/DattoRMM-Alert-HaloPSA bespoke modifications made to match Aegis Computers configuration

### Halo Custom field
Create a custom field on tickets in Halo with these details:
Field Name: DattoAlertType
Field Label: Datto RMM Alert Type
Input Type: Anything
Character Limit: Unlimited
Once created make a note of the ID of the newly created field. It will appear at the end of the URL after id=

### Variables
#### DattoURL
This is your Datto API URL, it can be found when you obtain an API key in Datto RMM.

#### DattoKey
This is your Datto API key for the script.

#### DattoSecretKey
This is your Datto API secret key for the script.

#### NumberOfColumns
This is the number of columns you would like to render in the email body of details sections.

#### HaloClientID
Create a Client ID and Secret API application in Halo. Assign the releveant permissions. This is the Client ID for that application.

#### HaloClientSecret
This is the Client Secret for the application you created in Halo.

#### HaloURL
This is the URL for your Halo instance.

#### HaloTicketStatusID
This is the ID of the status you would like tickets to be set to when created. You can get this by selecting the status in /config/tickets/status and looking at the ID in the URL.

#### HaloCustomAlertTypeField
This is the ID for the custom field you created in Halo.

#### HaloTicketType
This is the ID of the ticket type you would like tickets created as in Halo. You can get this from /config/tickets/tickettype by clicking on the type and looking in the URL

#### HaloReocurringStatus
This is the status you would like to set tickets to if they reoccur.

## Installation
To Deploy you can click the below button and then configure the settings as detailed above.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2fOliverPerring%2fDattoRMM-Alert-HaloPSA%2fmain%2fDeployment%2fAzureDeployment.json)

## Setup in Datto RMM
To use this script you need to edit your monitors to send to a webhook.
First go to https://portal.azure.com/ and browse to your functiion app that was just deployed.
Click on Functions on the left hand side and then on 'Receive-Alert'.
At the top click on Get Function Url. This is the URL you will need to enter in Datto RMM as your webhook address.

Find the monitor you wish to edit in Datto RMM and set the URL as well as setting the body as below:
```
{
    "troubleshootingNote": "Refer to ITG for related information",
    "docURL": "url here",
    "showDeviceDetails": true,
    "showDeviceStatus": false,
    "showAlertDetails": true,
    "resolvedAlert": "false",
    "dattoSiteDetails": "[sitename]",
    "alertUID": "[alert_uid]",
    "alertMessage": "[alert_message]",
    "platform": "[platform]"
}
```

Save the monitor and then test it is working correctly before rolling it out for all your other monitors.

You can toggle individual details sections on and off for the monitor if they are not relevant and you can provide a link to your documentation as well as a quick troubleshooting message to help technicians with resolving issues faster.

## Troubleshooting 
If you have issues the easiest way to debug is to use VSCode with the Azure Functions extension. If you click on theAzure logo in the left and login, you can then find your function app from the list. Right click on the function and choose start streaming logs. Reset and alert so the webhook resends and look at any errors.
