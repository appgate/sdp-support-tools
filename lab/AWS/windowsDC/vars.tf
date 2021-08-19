variable "aws_region" {
    description = "EC2 Region for the VPC"
    type=string
}

variable "namespace" {
    description = "namespace tag"
    type=string
}

variable "envtag" {
    description = "env tag"
    type=string
}

variable "ownertag" {
    description = "owner tag"
    type=string
}

variable "keyname" {
    description = "EC2 keypair"
    type=string
}

variable "dc_ami" {
    description = "Windows AMI"
    type=string
}

variable "dc_hostname" {
  default = "dc"
}

variable "dc_domain" {
  default = "sdp.lab"
}

variable "windows_localadmin" {
  default = "windowsadmin"
}

variable "windows_localadmin_pw" {
  default = "Password123"
}

variable "vpc_state_path" {
  description = "Relative path to the location of the vpc terraform.tfstate file"
  default = "../vpc/terraform.tfstate"
}
