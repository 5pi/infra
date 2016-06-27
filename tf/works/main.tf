variable "domain" {
  type = "string"
  default = "int.5pi.de"
}

variable "do_token" {
  type = "string"
}

variable "cluster_state" {
  type = "string"
  default = "existing"
  description = "Set this to 'new' for initial cluster creation"
}

variable "servers" {
  default = 3
}

variable "ip_int_prefix" {
  type = "string"
  default = "10.128"
}

variable "image" {
  type = "string"
  default = "17491906"
}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "terraform"
  public_key = "${file("id_rsa.pub")}"
}

resource "digitalocean_droplet" "master" {
  count = "${var.servers}"
  name = "master${count.index}"
  image = "${var.image}"
  region = "ams3"
  size = "512mb"
  private_networking = true
  ssh_keys = [ "${digitalocean_ssh_key.default.id}" ]
  provisioner "file" {
      source = "configure.sh"
      destination = "/tmp/configure.sh"
  }
  provisioner "remote-exec" {
    # FUCK THIS. Silently fails with HEREDOC and multline echo..
    inline = [
      "echo 'DOMAIN=${var.domain}' > /etc/environment.tf",
      "echo 'INDEX=${count.index}' >> /etc/environment.tf",
      "echo 'NAME=etcd${count.index}.${var.domain}' >> /etc/environment.tf",
      "echo 'SERVERS=${var.servers}' >> /etc/environment.tf",
      "echo 'IP_INT_PREFIX=${var.ip_int_prefix}' >> /etc/environment.tf",
      "echo 'IP_PRIVATE=${self.ipv4_address_private}' >> /etc/environment.tf",
      "echo 'STATE=${var.cluster_state}' >> /etc/environment.tf",
      "chmod a+x /tmp/configure.sh",
      "/tmp/configure.sh"
    ]
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_record" "master_a" {
  count = "${var.servers}"
  domain = "${var.domain}"
  type = "A"
  name = "master${count.index}"
  value = "${element(digitalocean_droplet.master.*.ipv4_address_private, count.index)}"
}

resource "digitalocean_record" "etcd_srv" {
  count = "${var.servers}"
  domain = "${var.domain}"
  type = "SRV"
  weight = 50
  priority = 50
  port = 2380
  name = "_etcd-server._tcp"
  value = "${element(digitalocean_record.master_a.*.name, count.index)}"
}
