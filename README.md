# AWS EC2 + Minikube + Full Observability (Prometheus + CloudWatch)

This project provisions a **fully automated** single-node Kubernetes cluster using **Minikube on a Graviton t4g.medium** instance with:

- Prometheus + Grafana (kube-prometheus-stack)
- CloudWatch Logs via CloudWatch Agent (reliable ARM64 support)
- Sample app exposing metrics
- Publicly accessible Prometheus, Grafana, and app

## Architecture Diagram (ASCII)
Internet
└─→ Internet Gateway
└─→ Public Subnet (10.0.1.0/24)
└─→ t4g.medium EC2 (Amazon Linux 2 ARM64)
├─ Docker
├─ Minikube (Docker driver)
├─ kube-prometheus-stack (Prometheus + Grafana)
├─ CloudWatch Agent → /minikubeobs/fluentbit
└─ hello-kubernetes app → scraped by Prometheus


## How to Use

```bash
git clone https://github.com/yourname/minikube-observability-aws.git
cd minikube-observability-aws
terraform init
terraform apply -auto-approve

prometheus_url = "http://3.14.159.26:30000"
grafana_url     = "http://3.14.159.26:30001"
sample_app_url  = "http://3.14.159.26:30080"
ssh_command     = "ssh -i ec2_key.pem ec2-user@3.14.159.26"

Default Grafana login: admin / prom-operator

terraform destroy -auto-approve

rm ec2_key.pem
