#!/bin/bash


read -p "Destroy AppGate and Webservers? [yes] " sdpcontinue
sdpcontinue="${sdpcontinue:-yes}"
if [ "$sdpcontinue" = "yes" ]; then
  cd sdp
  terraform destroy -var-file="../generated_vars.tf" -compact-warnings -auto-approve
  cd ..
fi

read -p "Destroy Domain Controller? [yes] " dccontinue
dccontinue="${dccontinue:-yes}"
if [ "$dccontinue" = "yes" ]; then
  cd windowsDC
  terraform destroy -var-file="../generated_vars.tf" -compact-warnings -auto-approve
  cd ..
fi

read -p "Destroy VPC? [yes] " vpccontinue
vpccontinue="${vpccontinue:-yes}"
if [ "$vpccontinue" = "yes" ]; then
  cd vpc
  terraform destroy -var-file="../generated_vars.tf" -compact-warnings -auto-approve
  cd ..
fi

