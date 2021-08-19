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

variable "sdp_ami" {
    description = "AppGate SDP AMI"
    type=string
}

variable "web_ami" {
    description = "Ubuntu/Webserver AMI"
    type=string
}

variable "controller_instance_count" {
  default = "1"
}


variable "gateway_instance_count" {
  default = "1"
}


variable "logserver_instance_count" {
  default = "0"
}


variable "vpc_state_path" {
  description = "Relative path to the location of the vpc terraform.tfstate file"
  default = "../vpc/terraform.tfstate"
}
