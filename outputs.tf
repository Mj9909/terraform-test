output "ec2_public_ip" {
  value = aws_instance.minikube.public_ip
}

output "ssh_command" {
  value = "ssh -i ec2_key.pem ec2-user@${aws_instance.minikube.public_ip}"
}

output "cloudwatch_log_group" {
  value = "/${var.project_name}/fluentbit"
}

output "prometheus_url" {
  value = "http://${aws_instance.minikube.public_ip}:30000"
}

output "grafana_url" {
  value = "http://${aws_instance.minikube.public_ip}:30001"
}

output "sample_app_url" {
  value = "http://${aws_instance.minikube.public_ip}:30080"
}

output "bootstrap_time" {
  value = "Bootstrap takes ~10–12 minutes. Check progress with: tail -f /var/log/cloud-init-output.log"
}