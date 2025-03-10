Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"	
		write-host "$MyDate - $Message_Type : $Message"	
	}

# Variables
$Log_File = "C:\Windows\Debug\Autopilot_HashID.log"
$ClientID = ""
$Secret = ''                
$Site_URL = ""
$Folder_Location = ""
	
If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}

# Getting hardware hash	
$Get_SerialNumber = (gwmi win32_bios).SerialNumber
$Hardware_Hash_File = "C:\Windows\Temp\$env:computername" + "_$Get_SerialNumber" + "_HardwareHash.txt"
$Get_Hardware_Hash = (gwmi -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData
$Get_Hardware_Hash | out-file $Hardware_Hash_File	
	
# Installing/Importing pnp.powershell module
$Is_Nuget_Installed = $False     
If(!(Get-PackageProvider | where {$_.Name -eq "Nuget"}))
	{                                         
		Try
			{
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Scope currentuser -Force -Confirm:$False | out-null                                                                                                                 
				$Is_Nuget_Installed = $True 
				Write_Log -Message_Type "INFO" -Message "Package Nuget installed"				
			}
		Catch
			{
				$Is_Nuget_Installed = $False  
				Write_Log -Message_Type "INFO" -Message "Package Nuget not installed"								
			}
	}
Else
	{
		$Is_Nuget_Installed = $True      
	}


If($Is_Nuget_Installed -eq $True)
	{
		$Script:PnP_Module_Status = $False
		$Module_Name = "PnP.PowerShell"
		If (!(Get-InstalledModule $Module_Name -ErrorAction silentlycontinue)) 				
			{ 
				Try
					{
						Install-Module $Module_Name -Scope currentuser -Force -Confirm:$False -ErrorAction SilentlyContinue | out-null
						$PnP_Module_Status = $True			
						Write_Log -Message_Type "SUCCESS" -Message "Module PnP installed"					
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "Module PnP not installed"										
					}				
			} 
		Else
			{      
				Try
					{
						Import-Module $Module_Name -Force -ErrorAction SilentlyContinue 
						$PnP_Module_Status = $True	  
						Write_Log -Message_Type "SUCCESS" -Message "Module PnP imported"						
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "Module PnP not imported"										
					}										
			}                                                       
	}

# Authenticating to SharePoint and sending hardware hash file
If($PnP_Module_Status -eq $True)
	{ 
		Try
			{
				Connect-PnPOnline -Url $Site_URL -ClientId $ClientID -ClientSecret $Secret -WarningAction Ignore									
				$Sharepoint_Status = "OK"
				Write_Log -Message_Type "SUCCESS" -Message "Connexion SharePoint"								
			}
		Catch
			{
				$Sharepoint_Status = "KO"	
				Write_Log -Message_Type "ERROR" -Message "Connexion SharePoint"												
			}	 
	
		If($Sharepoint_Status -eq "OK")
			{
				Write_Log -Message_Type "INFO" -Message "Upload file"								
				Write_Log -Message_Type "INFO" -Message "File to upload: $Logs_Collect_Folder_ZIP"								

				Try
					{
						Add-PnPFile -Path $Hardware_Hash_File -Folder $Folder_Location #| out-null					
						Write_Log -Message_Type "SUCCESS" -Message "Uploading file"				
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "Uploading file"
						$Last_Error = $error[0]
						Write_Log -Message_Type "ERROR" -Message "$Last_Error"										
					}
			}	
	}	
	
	
