#   ------------    Update & Upgrade    ------------

sudo apt-get update && sudo apt-get upgrade -y

#   ------------    Jenkins Server Installation    ------------

sudo apt-get update
sudo apt install fontconfig openjdk-21-jre -y
java -version
    
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins -y
    
systemctl status jenkins.service
    
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

#   ------------    Docker Installation    ------------

sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo usermod -aG docker $USER
newgrp docker

#   ------------    SonarQube Server Container    ------------

docker run -d \
  --name SonarQube-Server \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:latest

#   ------------    Nexus Server Container    ------------

docker run -d \
  --name Nexus-Server \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  -p 8083:8083 \
  -v nexus-data:/nexus-data \
  sonatype/nexus3:latest

#   ------------    Trivy Scanner Installation    ------------

sudo apt-get update
sudo apt-get install -y wget apt-transport-https gnupg lsb-release

wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list

sudo apt-get update
sudo apt-get install trivy -y

#   ------------    Kubernetes Setup - Run below on MASTER & WORKER    ------------

# Update system
sudo apt update && sudo apt upgrade -y

# Disable swap (Kubernetes hates swap)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl params required by Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

#   ------------

sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key and repo (containerd is in Docker repo)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y containerd.io

# Configure containerd to use systemd cgroup driver (required for Kubernetes)
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Edit the config: enable systemd cgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

#   ------------

# Add Kubernetes apt repository
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#   ------------    Kubernetes Setup - Run below on MASTER only    ------------

# Replace with your actual network interface (e.g., ens33, eth0, enp0s3)
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
MASTER_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)

# Initialize cluster (using Calico CNI later, so we use --pod-network-cidr for Calico)
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \ # Works fine OR set as per your requirements
  --cri-socket unix:///var/run/containerd/containerd.sock \
  --control-plane-endpoint $MASTER_IP \
  --upload-certs


# Setup kubectl for your user

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# After it finishes, you will see a "kubeadm join" command – SAVE IT!

# Install Calico CNI (best for single-master clusters)

# On master node only
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Wait until all pods in calico-system are running
watch "kubectl get pods -n calico-system -o wide; echo; kubectl get nodes -o wide"
