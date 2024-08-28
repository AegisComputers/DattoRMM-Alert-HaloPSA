
# DattoRMM-Alerts-HaloPSA

This repository contains a script that takes **Datto RMM Alert Webhooks** and sends them to **Halo PSA**. It is a heavily updated version of [lwhitelock's DattoRMM-Alert-HaloPSA](https://github.com/lwhitelock/DattoRMM-Alert-HaloPSA) with bespoke modifications made to match specific internal structures.

## Features

- **Webhook Integration:** Automatically sends Datto RMM alerts to Halo PSA, simplifying alert management and ticket creation.
- **Customization Options:** Support for custom fields and ticket types in Halo.
- **Flexible Configuration:** Various variables can be customized, including Datto and Halo API credentials, ticket types, and webhook URL.
- **Azure Deployment:** The solution can be deployed on Azure, allowing for easy cloud integration and scalability.
- **Error Handling and Debugging:** Built-in support for Azure Functions logs to assist with troubleshooting.

## Halo Custom Field Setup

To get started with integrating Halo PSA, create a custom field in Halo as follows:

- **Field Name:** `DattoAlertType`
- **Field Label:** `Datto RMM Alert Type`
- **Input Type:** Any (you can choose the input type that works best for your workflow)
- **Character Limit:** Unlimited

Once created, make a note of the ID for this field. The ID will appear at the end of the URL in Halo's configuration page after `id=`.

> [!IMPORTANT]
> Ensure that you correctly note the custom field ID in Halo, as using the wrong ID can cause alerts to fail to match the correct field, leading to incomplete or incorrect ticket creation.

## Variables Configuration

These variables are required to configure the script:

- **`DattoURL`:** The Datto API URL (found when obtaining an API key in Datto RMM).
- **`DattoKey`:** The Datto API key for the script.
- **`DattoSecretKey`:** The Datto API secret key for the script.
- **`NumberOfColumns`:** Number of columns to render in the email body of the alert details sections.
- **`HaloClientID`:** The client ID for the API application you created in Halo (requires relevant permissions).
- **`HaloClientSecret`:** The secret key for the API application created in Halo.
- **`HaloURL`:** The URL for your Halo instance.
- **`HaloTicketStatusID`:** The ID for the status to assign tickets when created (found by navigating to `/config/tickets/status` in Halo).
- **`HaloCustomAlertTypeField`:** The ID of the custom field you created in Halo for tracking alert types.
- **`HaloTicketType`:** The ID for the type of ticket to create (found by navigating to `/config/tickets/tickettype` in Halo).
- **`HaloRecurringStatus`:** Status to assign to tickets when they reoccur.

> [!IMPORTANT]
> Incorrect configuration of these variables, particularly API credentials and IDs, can lead to failures in ticket creation, missed alerts, or unauthorized access issues. Double-check each value before deployment.

## Installation

To deploy this solution to Azure, click the button below. After deployment, configure the environment variables as detailed above.

**Note:** Not all environment variables will work right out of the box. Please review the script to ensure everything is customized for your environment.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2fOliverPerring%2fDattoRMM-Alert-HaloPSA%2fmain%2fDeployment%2fAzureDeployment.json)

## Setup in Datto RMM

To use this script, you must configure your monitors in Datto RMM to send alerts via webhook:

1. Navigate to the [Azure portal](https://portal.azure.com/) and locate your newly deployed function app.
2. Click on **Functions** from the left-hand side menu, then select **Receive-Alert**.
3. At the top, click on **Get Function URL**. This URL will be used as the webhook address in Datto RMM.

### Setting up the Webhook in Datto RMM

1. Find the monitor you want to edit in Datto RMM.
2. Set the webhook URL to the Function URL retrieved earlier.
3. Use the following JSON as the body of the webhook:

   ```json
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

4. Save the monitor and test it to ensure proper functionality before applying the webhook to additional monitors.

You can customize individual sections of the webhook, such as toggling the details, adding documentation URLs, or including troubleshooting notes for technicians.

> [!IMPORTANT]
> Testing the webhook on a single monitor before a full rollout is crucial to ensure all configurations work correctly. Misconfiguration could result in missing critical alerts.

## Troubleshooting

If you encounter issues, the easiest way to debug is to use **Visual Studio Code** with the Azure Functions extension.

1. Open VSCode and click on the **Azure logo** on the left.
2. Log in and locate your function app from the list.
3. Right-click on the function and select **Start Streaming Logs**.
4. Reset an alert to resend the webhook and check the logs for errors.

> [!IMPORTANT]
> If you notice frequent errors in the logs, consider reviewing your Azure Function's permissions and the configuration of your Datto and Halo APIs, as improper settings could prevent the function from executing correctly.
