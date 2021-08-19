# wait until we can access the AD. this is needed to prevent errors like:
#   Unable to find a default server with Active Directory Web Services running.
while ($true) {
    try {
        Get-ADDomain | Out-Null
        break
    } catch {
        Start-Sleep -Seconds 10
    }
}

# Sets user windowsadmin as a domain administrator. 
Add-ADGroupMember -Identity "Domain Admins" -Members "windowsadmin"

$adDomain = Get-ADDomain
$domain = $adDomain.DNSRoot
$domainDn = $adDomain.DistinguishedName
$usersAdPath = "CN=Users,$domainDn"
$msaAdPath = "CN=Managed Service Accounts,$domainDn"
$password = ConvertTo-SecureString -AsPlainText 'Password123' -Force

# Create 'intranetusers' group
New-ADGroup `
    -Path $usersAdPath `
    -Name 'intranetusers' `
    -GroupCategory 'Security' `
    -GroupScope 'DomainLocal'



# add John Doe.
$name = 'john.doe'
New-ADUser `
    -Path $usersAdPath `
    -Name $name `
    -UserPrincipalName "$name@$domain" `
    -EmailAddress "$name@$domain" `
    -GivenName 'John' `
    -Surname 'Doe' `
    -DisplayName 'John Doe' `
    -AccountPassword $password `
    -Enabled $true `
    -PasswordNeverExpires $true
# we can also set properties.
Set-ADUser `
    -Identity "CN=$name,$usersAdPath" `
    -HomePage "https://$domain/~$name"
# add user to the Domain Admins group.
Add-ADGroupMember `
    -Identity 'Domain Admins' `
    -Members "CN=$name,$usersAdPath"
# add user to the intranetusers group.
Add-ADGroupMember `
    -Identity 'intranetusers' `
    -Members "CN=$name,$usersAdPath"


# add Jane Doe.
$name = 'jane.doe'
New-ADUser `
    -Path $usersAdPath `
    -Name $name `
    -UserPrincipalName "$name@$domain" `
    -EmailAddress "$name@$domain" `
    -GivenName 'Jane' `
    -Surname 'Doe' `
    -DisplayName 'Jane Doe' `
    -AccountPassword $password `
    -Enabled $true `
    -PasswordNeverExpires $true


echo 'john.doe Group Membership'
Get-ADPrincipalGroupMembership -Identity 'john.doe' `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000

echo 'jane.doe Group Membership'
Get-ADPrincipalGroupMembership -Identity 'jane.doe' `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000


echo 'Domain Administrators'
Get-ADGroupMember `
    -Identity 'Domain Admins' `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000


echo 'Enabled Domain User Accounts'
Get-ADUser -Filter {Enabled -eq $true} `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000


