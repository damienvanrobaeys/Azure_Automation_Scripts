$params  = @{  
DeviceName ="$env:COMPUTERNAME"; 
Action ="Remove"  
}  

$webhookURI = "https://e92cfc59-eda2-4623-b29e-29eeb48a53c2.webhook.we.azure-automation.net/webhooks?token=8byxdKjN0bAp%2bwixjInBjo2%2bUTpTUnpdy678HeJ69mM%3d"

$body = ConvertTo-Json -InputObject $params  
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing  