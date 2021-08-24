provider "aws" {
  region  = "${var.aws_region}"
}

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "${path.module}/${var.vpc_state_path}"
  }
}

resource "aws_instance" "appgate-controller" {
  count         = "${var.controller_instance_count}"
  ami           = "${var.sdp_ami}"
  instance_type = "t3.medium"
  key_name = "${var.keyname}"
  subnet_id = "${data.terraform_remote_state.vpc.outputs.SDP-public-subnet-id}"
  security_groups = ["${data.terraform_remote_state.vpc.outputs.SDP-SG-id}"]
  tags = {
    Name  = "${var.namespace}-Controller-${count.index}"
    env = "${var.envtag}"
    owner = "${var.ownertag}"
   }
}

resource "aws_eip" "appgate-controller" {
  instance = aws_instance.appgate-controller[count.index].id
  count         = "${var.controller_instance_count}"
  vpc      = true
  tags = {
    Name = "${var.namespace}-controller-eip",
    env = "${var.envtag}",
    owner = "${var.ownertag}"
  }
}

resource "aws_instance" "appgate-gateway" {
  count         = "${var.gateway_instance_count}"
  ami           = "${var.sdp_ami}"
  instance_type = "t3.medium"
  key_name = "${var.keyname}"
  subnet_id = "${data.terraform_remote_state.vpc.outputs.SDP-public-subnet-id}"
  security_groups = ["${data.terraform_remote_state.vpc.outputs.SDP-SG-id}"]
  tags = {
    Name  = "${var.namespace}-Gateway-${count.index}"
    env = "${var.envtag}"
    owner = "${var.ownertag}"
   }
}

resource "aws_eip" "appgate-gateway" {
  instance = aws_instance.appgate-gateway[count.index].id
  count         = "${var.gateway_instance_count}"
  vpc      = true
  tags = {
    Name = "${var.namespace}-gateway-eip",
    env = "${var.envtag}",
    owner = "${var.ownertag}"
  }
}

resource "aws_instance" "appgate-logserver" {
  count         = "${var.logserver_instance_count}"
  ami           = "${var.sdp_ami}"
  instance_type = "t2.medium"
  key_name = "${var.keyname}"
  subnet_id = "${data.terraform_remote_state.vpc.outputs.SDP-public-subnet-id}"
  security_groups = ["${data.terraform_remote_state.vpc.outputs.SDP-SG-id}"]
  tags = {
    Name  = "${var.namespace}-Logserver-${count.index}"
    env = "${var.envtag}"
    owner = "${var.ownertag}"
   }
}

resource "aws_eip" "appgate-logserver" {
  instance = aws_instance.appgate-logserver[count.index].id
  count         = "${var.logserver_instance_count}"
  vpc      = true
  tags = {
    Name = "${var.namespace}-logserver-eip",
    env = "${var.envtag}",
    owner = "${var.ownertag}"
  }
}

resource "aws_instance" "webserver" {
  ami           = "${var.web_ami}"
  instance_type = "t3.micro"
  key_name = "${var.keyname}"
  subnet_id = "${data.terraform_remote_state.vpc.outputs.SDP-private-subnet-id}"
  security_groups = ["${data.terraform_remote_state.vpc.outputs.SDP-private-SG-id}"]
  associate_public_ip_address = true
  tags = {
    Name  = "${var.namespace}-Internal-Webserver"
    env = "${var.envtag}"
    owner = "${var.ownertag}"
   }
}


# Export Terraform variable values to an Ansible var_file
resource "local_file" "tf_ansible_vars_file_new" {
  content = <<-DOC
    # Ansible vars_file containing variable values from Terraform.
    # Generated by Terraform configuration.

    tf_cnt1_public_ip: ${join(",", aws_eip.appgate-controller.*.public_ip)}
    tf_cnt1_public_dns: ${join(",", aws_eip.appgate-controller.*.public_dns)}
    tf_cnt1_private_ip: ${join(",", aws_instance.appgate-controller.*.private_ip)}
    tf_gw1_public_ip: ${join(",", aws_eip.appgate-gateway.*.public_ip)}
    tf_gw1_public_dns: ${join(",", aws_eip.appgate-gateway.*.public_dns)}
    tf_gw1_private_ip: ${join(",", aws_instance.appgate-gateway.*.private_ip)}
    tf_webserver_public_ip: ${join(",", aws_instance.webserver.*.public_ip)}
    tf_webserver_private_ip: ${join(",", aws_instance.webserver.*.private_ip)}
    tf_vpc_private_subnet_cidr: ${data.terraform_remote_state.vpc.outputs.SDP-private-subnet-cidr}
   DOC
  filename = "./tf_ansible_vars_file.yml"
}


# Export Terraform vars as ansible hosts file
resource "local_file" "tf_ansible_hosts" {
  content = <<-DOC
    # Ansible vars_file containing variable values from Terraform.
    # Generated by Terraform configuration.

    [primary_controller]
    ${join(",", aws_eip.appgate-controller.*.public_ip)} tf_hostname="controller01" 

    [gateways]
    ${join(",", aws_eip.appgate-gateway.*.public_ip)} tf_hostname="gateway01" 

    [webserver]
    ${join(",", aws_instance.webserver.*.public_ip)} tf_hostname="webserver" ansible_connection=ssh ansible_user=ubuntu

    DOC
  filename = "./hosts"
}


