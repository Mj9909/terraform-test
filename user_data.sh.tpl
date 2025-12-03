#!/bin/bash
set -euo pipefail

# Variables from Terraform (use lowercase as passed from templatefile)
PROJECT_NAME="${project_name}"
REGION="${region}"
LOG_GROUP="/${project_name}/fluentbit"

# Update system
sudo yum update -y
sudo yum install -y jq tar wget curl git

# Install Docker
sudo amazon-linux-extras install docker -y
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker
sudo systemctl start docker

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Install Minikube (ARM64)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-arm64
sudo install minikube-linux-arm64 /usr/local/bin/minikube

# Start Minikube with Docker driver
sudo -u ec2-user minikube start --driver=docker --nodes=1 --cpus=2 --memory=3g

# Install Fluent Bit (official AWS package)
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent

# Configure Fluent Bit via CloudWatch Agent (simpler & supported)
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat <<EOF | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/containers/*.log",
            "log_group_name": "$LOG_GROUP",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      }
    }
  }
}
EOF

# Use CloudWatch Agent (better ARM64 support than Fluent Bit RPM)
sudo amazon-linux-extras install collectd -y
curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/arm64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Wait for cluster
sudo -u ec2-user minikube kubectl -- wait --for=condition=Ready nodes --all --timeout=300s

# Add Helm repos
sudo -u ec2-user helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
sudo -u ec2-user helm repo update

# Install kube-prometheus-stack
sudo -u ec2-user helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30001 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30000

# Deploy sample app with metrics
cat <<EOF | sudo -u ec2-user minikube kubectl -- apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-demo
  namespace: demo
  replicas: 2
  selector:
    matchLabels:
      app: metrics-demo
  template:
    metadata:
      labels:
        app: metrics-demo
    spec:
      containers:
      - name: app
        image: paulbouwer/hello-kubernetes:1.10
        ports:
        - containerPort: 8080
        env:
        - name: PROMETHEUS_METRICS
          value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: metrics-demo
  namespace: demo
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port:   "8080"
spec:
  selector:
    app: metrics-demo
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: metrics-demo-np
  namespace: demo
spec:
  type: NodePort
  selector:
    app: metrics-demo
  ports:
    - port: 8080
      nodePort: 30080
      protocol: TCP
EOF

echo "Bootstrap complete!" > /var/log/bootstrap-complete.log