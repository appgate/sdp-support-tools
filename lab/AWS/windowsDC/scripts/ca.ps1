# install the AD services and administration tools.
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools


# install the PSPKI module.
# see https://github.com/PKISolutions/PSPKI
# see https://www.powershellgallery.com/packages/PSPKI/3.7.2
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Install-Module -Name PSPKI -Force | Out-Null
Import-Module PSPKI


$domainDn = (Get-ADDomain).DistinguishedName
$caCommonName = 'Example Enterprise Root CA'

# configure the CA DN using the default DN suffix (which is based on the
# current Windows Domain, example.com) to:
#
#   CN=Example Enterprise Root CA,DC=example,DC=com
#
# NB to install a EnterpriseRootCa the current user must be on the
#    Enterprise Admins group.
Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCa `
    -CACommonName $caCommonName `
    -HashAlgorithmName SHA256 `
    -KeyLength 4096 `
    -ValidityPeriodUnits 8 `
    -ValidityPeriod Years `
    -Force

# export the certificate (in pem format) , so it can be used by other machines.
#$fulldomain="$env:computername.$env:userdnsdomain"
#
#dir Cert:\LocalMachine\My -DnsName $fulldomain `
#    | Export-Certificate -FilePath "C:\windows\temp\full.der" -type CERT `
#    | Out-Null
#
#certutil -encode C:\windows\temp\full.der C:\windows\temp\full.pem


Restart-Computer
