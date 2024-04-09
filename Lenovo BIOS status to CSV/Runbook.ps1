#*****************************************************************
# Information about the SharePoint where to send CSV and Azure app registration
$Tenant = ""  # tenant name
$ClientID = "" # azure app client id 
$Secret = '' # azure app secret
$SharePoint_SiteID = ""  # sharepoint site id	
$SharePoint_Path = ""  # sharepoint main path
$SharePoint_ExportFolder = ""  # folder where to upload file

# Teams webhoot link
$Webhook_URL = ""

# Teams notif design
$Notif_Title = "BIOS status on Lenovo devices"
$Notif_Message = "Here is a list of devices with current BIOS version and latest one available on Lenovo website."
$Color = "2874A6"

$CSV_Name = "Devices_with_old_BIOS.csv"
$Exported_CSV_URL = ""
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


$Devices_URL = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter' + "=contains(operatingSystem,'Windows')"
$All_Devices = Invoke-WebRequest -Uri $Devices_URL -Method GET -Headers $Headers -UseBasicParsing 
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

$Devices_Array = @()
$Getting_XML_Info = $False
$Getting_BIOS_Location = $False 
$Getting_BIOS_Version = $False

$Lenovo_Devices = $Get_All_Devices | where {(($_.operatingSystem -eq "windows") -and ($_.manufacturer -eq "lenovo"))}
ForEach($Device in $Lenovo_Devices)
    {
        $Device_ID = $Device.id
        $Device_Name = $Device.deviceName
        $Device_enrolledDateTime = $Device.enrolledDateTime
        $Device_lastSyncDateTime = $Device.lastSyncDateTime
        $Device_userPrincipalName = $Device.userPrincipalName
        $Device_model = $Device.model
        $Get_MTM = ($Device_model.SubString(0, 4)).Trim()
        $Device_serialNumber = $Device.serialNumber
        $Device_userDisplayName = $Device.userDisplayName        

        $Current_Device_URL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/" + $Device_ID + "?`$select=hardwareInformation"
        $Current_Device_Info = Invoke-WebRequest -Uri $Current_Device_URL -Method GET -Headers $Headers -UseBasicParsing 
        $Current_Device_Info_JsonResponse = ($Current_Device_Info.Content | ConvertFrom-Json)
        
        $Device_Current_BIOS = $Current_Device_Info_JsonResponse.hardwareInformation.systemManagementBIOSVersion
        If($Device_Current_BIOS -eq $null)
            {
                $Current_BIOS_Version = "Can not get the info"
            }
        Else
            {
                If($Device_Current_BIOS -like "*.*")
                    {
                        $Current_BIOS_Version = $Device_Current_BIOS.split("(").replace(")","")[1]

                    }
                Else
                    {
                        $Current_BIOS_Version = $Device_Current_BIOS
                    }            
            }

        $WindowsVersion2 = "win10"       
        $CatalogUrl = "https://download.lenovo.com/catalog/$Get_MTM`_$WindowsVersion2.xml"
        [System.Xml.XmlDocument]$CatalogXml = (New-Object -TypeName System.Net.WebClient).DownloadString($CatalogUrl)
        try
            {
                [System.Xml.XmlDocument]$CatalogXml = (New-Object -TypeName System.Net.WebClient).DownloadString($CatalogUrl)
                $Getting_XML_Info = $True  
            }
        catch
            {
                $Last_BIOS_Version = "Can not get info"
                $BIOS_Status = "Can not get info"
                $Getting_XML_Info = $False                		
            }

        If($Getting_XML_Info -eq $True)
            {
                $PackageUrls = ($CatalogXml.packages.ChildNodes | Where-Object { $_.category -match "BIOS UEFI" }).location
                If($PackageUrls -eq $null)
                    {
                        $Last_BIOS_Version = "Can not get info"
                        $BIOS_Status = "Can not get info"
                        $Getting_BIOS_Location = $False	                        
                    }
                Else
                    {
                        If($PackageUrls.Count -eq 0)
                            {
                                $Last_BIOS_Version = "Can not get info"
                                $BIOS_Status = "Can not get info"
                                $Getting_BIOS_Location = $False	
                            }                        
                        ElseIf($PackageUrls.Count -eq 1)
                            {
                                [System.Xml.XmlDocument]$PackageXml = (New-Object -TypeName System.Net.WebClient).DownloadString($PackageUrls)		
                                $Getting_BIOS_Location = $True
                            }
                        ElseIf($PackageUrls.Count -gt 1)
                            {
                                $Last_BIOS_Version = "Multiple versions available"
                                $BIOS_Status = "Multiple versions available"    
                                $Getting_BIOS_Location = $False
                            }                    
                    }
            }

        If($Getting_BIOS_Location -eq $True)
            {
                $baseUrl = $PackageUrls.Substring(0,$PackageUrls.LastIndexOf('/')+1)
                $Last_BIOS_Version = $PackageXml.Package.version	
                If($Last_BIOS_Version -eq $null)
                    {
                        $Last_BIOS_Version = "Can not get info"
                        $BIOS_Status = "Can not get info"
                        $Getting_BIOS_Version = $False			
                    }
                Else
                    {
                        $Getting_BIOS_Version = $True
                    }
            }

        If($Getting_BIOS_Version -eq $True)
            {
                $Get_Current_Date = get-date
                $Last_BIOS_Date = $PackageXml.Package.ReleaseDate 
                If($Last_BIOS_Date -ne $null)
                    {
                        $Get_Converted_BIOS_Date = [datetime]::parseexact($Last_BIOS_Date, 'yyyy-MM-dd', $null)
                    }

                $Last_BIOS_Version = $Last_BIOS_Version.trim()

                If($Device_Current_BIOS -ne $null)
                    {
                        $Current_BIOS_Version = $Current_BIOS_Version.trim()
                        If($Last_BIOS_Version -ne $Current_BIOS_Version)
                            {
                                $BIOS_Status = "Not uptodate"
                                If($Last_BIOS_Date -ne $null)
                                    {
                                        $Diff_LastBIOS_and_Today = $Get_Current_Date - $Get_Converted_BIOS_Date        
                                        $Diff_in_days = $Diff_LastBIOS_and_Today.Days    
                                    }         
                            }
                        Else 
                            {
                                $BIOS_Status = "Uptodate"
                            }
                    }
                Else
                    {
                        $BIOS_Status = "Can not get info"
                    }
            }

        $Obj = New-Object PSObject
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device" -Value $Device_Name	
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Model" -Value $Get_MTM	
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "SN" -Value $Device_serialNumber
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last sync" -Value $Device_lastSyncDateTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "User" -Value $Device_userPrincipalName
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Current BIOS version" -Value $Current_BIOS_Version	
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last BIOS version" -Value $Last_BIOS_Version		
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last BIOS Date" -Value $Last_BIOS_Date	
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "BIOS status" -Value $BIOS_Status
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "New version published since (in days)" -Value $Diff_in_days	      	 
        $Devices_Array += $Obj
    }

$Devices_Not_Uptodate = ($Devices_Array | where {($_."BIOS Status" -eq "Not uptodate")}).count
$Devices_Uptodate = ($Devices_Array | where {($_."BIOS Status" -eq "Uptodate")}).count
$Devices_NoInfo = ($Devices_Array | where {($_."BIOS Status" -eq "Can not get info")}).count
$Lenvo_Devices_Count = $Lenovo_Devices.count
$Devices_MultipleVersions = ($Devices_Array | where {($_."BIOS Status" -eq "Multiple versions available")}).count

$NewFile = New-Item -ItemType File -Name $CSV_Name
$Devices_Array | select * | export-csv $CSV_Name -notype -Delimiter ";"

$Body = @{  
    client_id = $ClientID
    client_secret = $Secret
    scope = "https://graph.microsoft.com/.default"   
    grant_type = 'client_credentials'  
}  
    
$Graph_Url = "https://login.microsoftonline.com/$($Tenant).onmicrosoft.com/oauth2/v2.0/token"  
Try
	{
		$AuthorizationRequest = Invoke-RestMethod -Uri $Graph_Url -Method "Post" -Body $Body  
	}
Catch
	{
		EXIT
	}
	
$Access_token = $AuthorizationRequest.Access_token  
$Header = @{  
    Authorization = $AuthorizationRequest.access_token  
    "Content-Type"= "application/json"  
    'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"	
}  

$SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"  
$BodyJSON = $Body | ConvertTo-Json -Compress  

Try
	{
		$Result = Invoke-RestMethod -Uri $SharePoint_Graph_URL -Method 'GET' -Headers $Header -ContentType "application/json"   
	}
Catch
	{
		EXIT
	}

$DriveID = $Result.value| Where-Object {$_.webURL -eq $SharePoint_Path } | Select-Object id -ExpandProperty id  

$FileName = $CSV_Name.Split("\")[-1]  
$createUploadSessionUri = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/createUploadSession"

Try
	{
		$uploadSession = Invoke-RestMethod -Uri $createUploadSessionUri -Method 'POST' -Headers $Header -ContentType "application/json" 
	}
Catch
	{
		EXIT
	}

$fileInBytes = [System.IO.File]::ReadAllBytes($CSV_Name)
$fileLength = $fileInBytes.Length

$headers = @{
  'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"
}

Try
	{
		$response = Invoke-RestMethod -Method 'Put' -Uri $uploadSession.uploadUrl -Body $fileInBytes -Headers $headers
	}
Catch
	{
		EXIT
	}

$body = @"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "$Notif_Title",
    "title": "$Notif_Title",

    "potentialAction": [{
        "@type": "OpenUri",
        "name": "View the list of devices",
        "targets": [{
            "os": "default",
            "uri": "$Exported_CSV_URL"
        }]
    }],
    "sections": [
        {
            "text": "$Notif_Message<br>- Devices with BIOS not uptodate: $Devices_Not_Uptodate<br>- Devices with BIOS uptodate: $Devices_Uptodate<br>- Devices with no BIOS info: $Devices_NoInfo<br>- Lenovo devices: $Lenvo_Devices_Count"
        },	
    ]	

}
"@
Invoke-RestMethod -uri $Webhook_URL -Method Post -body $body -ContentType 'application/json'    