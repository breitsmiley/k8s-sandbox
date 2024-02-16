output "ec2_k8s_master" {
  value = {
    "public_ip" = aws_eip.k8s_master_eip.public_ip
  }
}

output "ec2_k8s_worker" {
  value = {
    "public_ip" = aws_eip.k8s_worker_eip.public_ip
  }
}

#output "aws_key_pair" {
#  value = aws_key_pair.k8s_ssh_key
#}

