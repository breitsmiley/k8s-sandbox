variable "region" {
  default = "eu-central-1"
}

variable "k8s_ssh_key" {
  description = "SSH public key string"
  default     = ""
}

variable "k8s_ssh_key_path" {
  description = "Path to public key file"
  default     = "~/.ssh/id_rsa.pub"
}
