#*****************************************************************
# Delete the entry from the autopilot devices part after adding the coroporate device id
$Delete_hardwarehash = $true # or $false

# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Mail_From = ""
$Mail_To = ""

# Name of the CSV file
$CSV_File = "Autopilot_v2_Migration.csv"

# Notif content
$Notif_Title = "Autopilot v2 migration"
$Notif_Message = "Here is the list of devices migrated from hardware hash to corporate device identifiers"
#*****************************************************************

# Getting a token and authenticating to your tenant using the managed identity
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

$AutopilotDevices__URL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
$ImportDevices_URL = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList"

# Getting all devices from the autopilot devices side
$All_Devices = Invoke-WebRequest -Uri $AutopilotDevices__URL -Method GET -Headers $Headers -UseBasicParsing 
$All_Devices_JsonResponse = ($All_Devices.Content | ConvertFrom-Json)
$Get_All_Devices = $All_Devices_JsonResponse.value
If($All_Devices_JsonResponse.'@odata.nextLink')
{
    do {
        $URL = $All_Devices_JsonResponse.'@odata.nextLink'
        $All_Devices = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing 
        $All_Devices_JsonResponse = ($All_Devices.Content | ConvertFrom-Json)
        $Get_All_Devices += $All_Devices_JsonResponse.value
    } until ($null -eq $All_Devices_JsonResponse.'@odata.nextLink')
}

$Get_All_Autopilot_Devices = $Get_All_Devices | select -first 5

$Autopilotv2_Migration_Array = @()	
ForEach($Devices in $Get_All_Autopilot_Devices)
    {
        $Manufacturer = $Devices.Manufacturer
        $Model = $Devices.Model
        $SerialNumber = $Devices.SerialNumber
        $DeviceIdentifier = "$Manufacturer,$Model,$SerialNumber" 

$Body = @{
    overwriteImportedDeviceIdentities = $false
    importedDeviceIdentities = @(
        @{
            importedDeviceIdentityType = "manufacturerModelSerial"
            importedDeviceIdentifier = "$DeviceIdentifier"
        }
    )
}

$JSON = $Body | convertto-json

        Try
            {
                Invoke-RestMethod -Uri $ImportDevices_URL -Method Post  -Body $JSON -Headers $Headers -ContentType "application/json"
                $Corporate_ID_Status = "Device added in corporate device identifiers"
                $Corporate_ID_added = "OK"

            }
        Catch
            {
                $Corporate_ID_Status = "Failed to add the device in corporate device identifiers"
                $Corporate_ID_added = "KO"
            }

        If($Corporate_ID_added -eq "OK")
            {
                Try
                    { 
                        $Get_Autopilot_Devices_URL = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?$filter' + "=contains(serialNumber,'$SerialNumber')"		
                        $Autopilot_info = Invoke-WebRequest -Uri $Get_Autopilot_Devices_URL -Method GET -Headers $Headers -UseBasicParsing         
                        $Autopilot_info_JsonResponse = ($Autopilot_info.Content | ConvertFrom-Json)
                        $Check_Device_InAutopilot = $Autopilot_info_JsonResponse.value
                        $autopilot_id = $Check_Device_InAutopilot.id
                        If($autopilot_id -ne $null)
                            {
                                $Autopilot_Status = "Exists in Autopilot"

                                If($Delete_hardwarehash -eq $true)
                                    {
                                        $Autopilot_device_url = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$autopilot_id"
                                        Try 
                                            {
                                                Invoke-WebRequest -Uri $Autopilot_device_url -Method DELETE -Headers $Headers -UseBasicParsing    
                                                $Autopilot_Delete_Status = "OK"
                                            }
                                        Catch
                                            {
                                                $Autopilot_Delete_Status = "KO"
                                            }
                                    }
                                Else
                                    {
                                        $Autopilot_Delete_Status = ""
                                    }
                            }
                        Else
                            {
                                $Autopilot_Status = "Not found in Autopilot"
                            }
                    }
                Catch
                    { 
                        $Autopilot_Status = "Can not get info about the device in Autopilot"
                    }
            }
        Else
            {
                $Autopilot_Status = "NA"
                $Autopilot_Delete_Status = "NA"
            }

        If($Send_Mail -eq $True)
            {
                $Obj = New-Object PSObject
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Manufacturer" -Value $Manufacturer	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Model" -Value $Model
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "SerialNumber" -Value $SerialNumber	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "DeviceIdentifier" -Value $DeviceIdentifier
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Corporate ID added" -Value $Corporate_ID_Status	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device in Autopilot" -Value $Autopilot_Status	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Autopilot deleted" -Value $Autopilot_Delete_Status	   
                $Autopilotv2_Migration_Array += $Obj  
            }           
    }

If($Send_Mail -eq $True)
    {
        $NewFile = New-Item -ItemType File -Name $CSV_File
        $Autopilotv2_Migration_Array | select * | export-csv $CSV_File -notype -Delimiter ";"  

        $Text_Message = "$Notif_Message"

        Connect-MgGraph -Identity | out-null

        $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File))
        $attachmentname = (Get-Item -Path $CSV_File).Name

        $params = @{
            Message         = @{
                Subject       = $Notif_Title
                Body          = @{
                    ContentType = "HTML"
                    Content     = $Text_Message
                }
                ToRecipients  = @(
                    @{
                        EmailAddress = @{
                            Address = $Mail_To
                        }
                    }
                )
                Attachments   = @(
                    @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        Name          = $attachmentname
                        ContentType   = "text/plain"
                        ContentBytes  = $attachmentmessage
                    }
                )
            }
            SaveToSentItems = "false"
        }

        Send-MgUserMail -UserId $Mail_From -BodyParameter $params                
    }
