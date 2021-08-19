#!/bin/bash

# Prevents python fork crash
# Example error:
# objc[47125]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called.
# objc[47125]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called. We cannot safely call it or ignore it in the fork() child process. Crashing instead. Set a breakpoint on objc_initializeAfterForkError to debug.
# ERROR! A worker was found in a dead state
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Prevents AWS Cli dumping to less/vi
export AWS_PAGER=""

function buildit {
read -p "Build VPC? [yes] " vpccontinue
vpccontinue="${vpccontinue:-yes}"
if [ "$vpccontinue" = "yes" ]; then
  cd vpc
  terraform init
  terraform apply -var-file="../generated_vars.tf" -compact-warnings -auto-approve
  cd ..
fi

read -p "Build Domain Controller? [yes] " dccontinue
dccontinue="${dccontinue:-yes}"
if [ "$dccontinue" = "yes" ]; then
  cd windowsDC
  terraform init
  terraform apply -var-file="../generated_vars.tf" -compact-warnings -auto-approve
  cd ..
fi

read -p "Build AppGate and Webservers? [yes] " sdpcontinue
sdpcontinue="${sdpcontinue:-yes}"
if [ "$sdpcontinue" = "yes" ]; then
  cd sdp
  terraform init
  terraform apply -var-file="../generated_vars.tf" -compact-warnings -auto-approve

  if test -f "../windowsDC/tf_ansible_vars_file.yml"; then
       ansible-playbook -i hosts --private-key $keyfile add-dns-entries.yaml
       ansible-playbook -i hosts --private-key $keyfile seed-controllers.yaml
       ansible-playbook -i hosts --private-key $keyfile get-api-token.yaml
       ansible-playbook -i hosts --private-key $keyfile get-healthy-controller.yaml
       ansible-playbook -i hosts --private-key $keyfile setup-ad-idp.yaml
       ansible-playbook -i hosts --private-key $keyfile ad-cert.yaml
       ansible-playbook -i hosts --private-key $keyfile reboot-controller.yaml
       ansible-playbook -i hosts --private-key $keyfile get-healthy-controller.yaml
       ansible-playbook -i hosts --private-key $keyfile add-entitlement-pol.yaml
       ansible-playbook -i hosts --private-key $keyfile seed-gateway.yaml
       ansible-playbook -i hosts --private-key $keyfile setup-webserver.yaml
       ansible-playbook -i hosts --private-key $keyfile setup-client.yaml

       read -p "Copy the above profile link to ../vagrant/windowsClient/ ? [yes] " copyprofile
       copyprofile="${copyprofile:-yes}"
       if [ "$copyprofile" = "yes" ]; then
         echo "Moving profile.txt to vagrant/windowsClient folder"
         mv profile.txt ../../vagrant/windowsClient/provision/
       fi
  fi

  cd ..

fi
}

### VERIFY AWS CREDS/CONNECTION ###

aws sts get-caller-identity --output table || exit
read -p "Is this you? Continue? [yes] " mecontinue
mecontinue="${mecontinue:-yes}"
if [ "$mecontinue" != "yes" ]; then
    exit 
fi

### REUSE CONFIG ###
if test -f "./generated_vars.tf"; then
  echo "Existing generated_vars.tf file found.  It contains..."
  cat ./generated_vars.tf
  read -p "Reuse this config? [yes] " reuseconfig
  reuseconfig="${reuseconfig:-yes}"
  if [ "$reuseconfig" = "yes" ]; then
      read -e -p "Enter full path to SSH keyfile for key $keypair:  " keyfile
      if [ ! -f $keyfile ]; then
          echo "ERROR:  File SSH Key does not exist!"
          exit
      fi
      # Build it
      buildit
      exit
  fi
  
fi  

### TAGS ###
echo ""
echo "Enter a namespace/prefix to use.  This is useful when viewing resources in the AWS console."
echo "Instead of seeing an entire list of EC2 instances labeled \"AppGateSDP-Contoller01\" it would show \"amartin-AppgateSDP-Contoller01\"."
read -p "What namespace/prefix to use? (example: amartin):  " namespace
echo ""
read -p "What environment tag? (examples: dev, sandbox, prod, etc..):  " envtag
echo ""
read -p "What is the owner tag? (example: andrew.martin@appgate.com):  " ownertag
echo ""



### SELECT REGION ###

oIFS="$IFS"
IFS=$'\n'
# Typically you do not need to specify the region for the "describe-regions" command, but this allows to to avoid errors if the ~/.aws/config file is missing.  I set it to us-east-2, but shows all that we have access to, filtered to US and EU.
regions=(`aws ec2 describe-regions --region us-east-2 --filters "Name=endpoint,Values=*us*,*eu*" --query "Regions[].{Name:RegionName}" --output text || exit`)
IFS="$oIFS"

echo "Please select AWS Region to deploy to:  "
select region in "${regions[@]}"; do
  [[ -n $region ]] || { echo "Invalid choice. Please try again." >&2; continue; }
  break # valid choice was made; exit prompt.
done

echo $region


### SELECT APPGATE SDP AMI ###

oIFS="$IFS"
IFS=$'\n'
SDPAMIs=(`aws ec2 describe-images --region $region --owners aws-marketplace --filters "Name=name,Values=*AppGate-SDP-5*BYOL*" --query "Images[*].[ImageId,Name]" --output text || exit`) 
IFS="$oIFS"

echo "Please select an AppGate AMI:"
select choice in "${SDPAMIs[@]}"; do
  [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
  break # valid choice was made; exit prompt.
done

echo $choice
sdpamiid=`echo $choice | awk '{print $1;}'`
echo $sdpamiid


### SELECT WINDOWS DC AMI ###

oIFS="$IFS"
IFS=$'\n'
WINAMIs=(`aws ec2 describe-images --region $region --owners amazon --filters "Name=name,Values=Windows_Server-2019-English-Full-Base*" --query "Images[*].[ImageId,Name]" --output text || exit`)
IFS="$oIFS"

echo "Please select an AMI for the Windows DC:  "
select choice in "${WINAMIs[@]}"; do
  [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
  break # valid choice was made; exit prompt.
done

echo $choice
dcamiid=`echo $choice | awk '{print $1;}'`
echo $dcamiid


### SELECT UBUNTU/WEBSERVER AMI ###

oIFS="$IFS"
IFS=$'\n'
WEBAMIs=(`aws ec2 describe-images --region $region --owners 099720109477 --filters "Name=name,Values=*ubuntu-groovy-20.10-amd64-server-2021*" --query "Images[*].[ImageId,Name]" --output text || exit`)
IFS="$oIFS"

echo "Please select an AMI for Ubuntu Webserver:  "
select choice in "${WEBAMIs[@]}"; do
  [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
  break # valid choice was made; exit prompt.
done

echo $choice
webamiid=`echo $choice | awk '{print $1;}'`
echo $webamiid



### KEYPAIR STUFF ###

echo "Use existing SSH key or create new?"
echo "1) Existing"
echo "2) New"
read choice
case $choice in
  1)
     keypairs=(`aws ec2 describe-key-pairs --region $region --output text | awk '{print $3'} || exit`)
     if [ ${#keypairs[@]} -eq 0 ]; then
       echo "No keypairs found.  Exiting."
       exit
     fi
     select keypair in "${keypairs[@]}"; do
       [[ -n $keypair ]] || { echo "Invalid choice. Please try again." >&2; continue; }
       break # valid choice was made; exit prompt.
     done

     read -e -p "Enter full path to SSH keyfile for key $keypair:  " keyfile
     if [ ! -f $keyfile ]; then
         echo "ERROR:  File SSH Key does not exist!"
         exit
     fi

     ;;
  2)
     read -p "What key name to create? (example: MyKeyPair):  " keynameinput
     keyfile=$HOME/.ssh/$keynameinput.pem
     echo "Creating key $keynameinput..."
     aws ec2 create-key-pair --key-name $keynameinput --region $region --query 'KeyMaterial' --output text > $keyfile || exit
     chmod 600 $keyfile
     echo "Key PEM stored locally at:  $keyfile"
     keypair=$keynameinput
     
     ;;
esac


# Create Var File for terraform
cat > generated_vars.tf << EOF

keyname = "$keypair"
sdp_ami = "$sdpamiid"
dc_ami = "$dcamiid"
web_ami = "$webamiid"
aws_region  = "$region"
namespace = "$namespace"
envtag = "$envtag"
ownertag = "$ownertag"

EOF

# Build it
buildit

