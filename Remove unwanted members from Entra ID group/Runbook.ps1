#*****************************************************************
$Group_ID = ""
$WhiteList = @("ID1",
"ID2",
"ID3"
)
#*****************************************************************

# Authenticate to the managed identity for Intune
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity

# Getting group members
$Get_Group_Members = (Get-AzADGroupMember -GroupObjectId $Group_ID) 
$Unwanted_Members = $Get_Group_Members | Where-Object {
    $item = $_
    -not ($whitelist | Where-Object {
        $_ -eq $item.id
    })
}

If($Unwanted_Members){
    $Unwanted_Users_Count = $Unwanted_Members.Count
    Write-Output "Members in the group but not in the whitelist: $Unwanted_Users_Count"
    ForEach($Member in $Unwanted_Members)
        {
            $Member_ID = $Member.id
            $Member_DisplayName = $Member.DisplayName
            "$Member_DisplayName is here but not in the whitelist and will be removed from the group"
            Try{
                    Remove-AzADGroupMember -GroupObjectId $Deployment_Completed_Group_ID  -MemberObjectId $Member_ID
                    "Member $Member_DisplayName has been removed from the group"
            }
            Catch{
                    "Member $Member_DisplayName has not been removed from the group"
            }
        }
}

