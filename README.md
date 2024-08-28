
<h1>DattoRMM-Alerts-HaloPSA</h1>

<p>This repository contains a script that takes <strong>Datto RMM Alert Webhooks</strong> and sends them to <strong>Halo PSA</strong>. It is a heavily updated version of <a href="https://github.com/lwhitelock/DattoRMM-Alert-HaloPSA">lwhitelock's DattoRMM-Alert-HaloPSA</a> with bespoke modifications made to match specific internal structures.</p>

<h2>Features</h2>

<ul>
<li><strong>Webhook Integration:</strong> Automatically sends Datto RMM alerts to Halo PSA, simplifying alert management and ticket creation.</li>
<li><strong>Customization Options:</strong> Support for custom fields and ticket types in Halo.</li>
<li><strong>Flexible Configuration:</strong> Various variables can be customized, including Datto and Halo API credentials, ticket types, and webhook URL.</li>
<li><strong>Azure Deployment:</strong> The solution can be deployed on Azure, allowing for easy cloud integration and scalability.</li>
<li><strong>Error Handling and Debugging:</strong> Built-in support for Azure Functions logs to assist with troubleshooting.</li>
</ul>

<h2>Halo Custom Field Setup</h2>

<p>To get started with integrating Halo PSA, create a custom field in Halo as follows:</p>

<ul>
<li><strong>Field Name:</strong> <code>DattoAlertType</code></li>
<li><strong>Field Label:</strong> <code>Datto RMM Alert Type</code></li>
<li><strong>Input Type:</strong> Any (you can choose the input type that works best for your workflow)</li>
<li><strong>Character Limit:</strong> Unlimited</li>
</ul>

<p>Once created, make a note of the ID for this field. The ID will appear at the end of the URL in Halo's configuration page after <code>id=</code>.</p>

<h2>Variables Configuration</h2>

<p>These variables are required to configure the script:</p>

<ul>
<li><strong><code>DattoURL</code>:</strong> The Datto API URL (found when obtaining an API key in Datto RMM).</li>
<li><strong><code>DattoKey</code>:</strong> The Datto API key for the script.</li>
<li><strong><code>DattoSecretKey</code>:</strong> The Datto API secret key for the script.</li>
<li><strong><code>NumberOfColumns</code>:</strong> Number of columns to render in the email body of the alert details sections.</li>
<li><strong><code>HaloClientID</code>:</strong> The client ID for the API application you created in Halo (requires relevant permissions).</li>
<li><strong><code>HaloClientSecret</code>:</strong> The secret key for the API application created in Halo.</li>
<li><strong><code>HaloURL</code>:</strong> The URL for your Halo instance.</li>
<li><strong><code>HaloTicketStatusID</code>:</strong> The ID for the status to assign tickets when created (found by navigating to <code>/config/tickets/status</code> in Halo).</li>
<li><strong><code>HaloCustomAlertTypeField</code>:</strong> The ID of the custom field you created in Halo for tracking alert types.</li>
<li><strong><code>HaloTicketType</code>:</strong> The ID for the type of ticket to create (found by navigating to <code>/config/tickets/tickettype</code> in Halo).</li>
<li><strong><code>HaloRecurringStatus</code>:</strong> Status to assign to tickets when they reoccur.</li>
</ul>

<h2>Installation</h2>

<p>To deploy this solution to Azure, click the button below. After deployment, configure the environment variables as detailed above.</p>

<p>Note: Not all environment variables will work right out of the box. Please review the script to ensure everything is customized for your environment.</p>

<p><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2fOliverPerring%2fDattoRMM-Alert-HaloPSA%2fmain%2fDeployment%2fAzureDeployment.json"><img src="https://aka.ms/deploytoazurebutton" alt="Deploy to Azure" /></a></p>

<h2>Setup in Datto RMM</h2>

<p>To use this script, you must configure your monitors in Datto RMM to send alerts via webhook:</p>

<ol>
<li>Navigate to the <a href="https://portal.azure.com/">Azure portal</a> and locate your newly deployed function app.</li>
<li>Click on <strong>Functions</strong> from the left-hand side menu, then select <strong>Receive-Alert</strong>.</li>
<li>At the top, click on <strong>Get Function URL</strong>. This URL will be used as the webhook address in Datto RMM.</li>
</ol>

<h3>Setting up the Webhook in Datto RMM</h3>

<ol>
<li>Find the monitor you want to edit in Datto RMM.</li>
<li>Set the webhook URL to the Function URL retrieved earlier.</li>
<li>Use the following JSON as the body of the webhook:</li>

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

<p>Save the monitor and test it to ensure proper functionality before applying the webhook to additional monitors.</p>
</ol>

<p>You can customize individual sections of the webhook, such as toggling the details, adding documentation URLs, or including troubleshooting notes for technicians.</p>

<h2>Troubleshooting</h2>

<p>If you encounter issues, the easiest way to debug is to use <strong>Visual Studio Code</strong> with the Azure Functions extension.</p>

<ol>
<li>Open VSCode and click on the <strong>Azure logo</strong> on the left.</li>
<li>Log in and locate your function app from the list.</li>
<li>Right-click on the function and select <strong>Start Streaming Logs</strong>.</li>
<li>Reset an alert to resend the webhook and check the logs for errors.</li>
</ol>
