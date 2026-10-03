#!/bin/bash
set -euxo pipefail
# 2 GB swap so Jenkins + Docker builds survive on a small instance
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

dnf install -y docker git python3 java-17-amazon-corretto-headless
systemctl enable --now docker

curl -fsSL -o /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
usermod -aG docker jenkins
systemctl enable --now jenkins
# Unlock password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword  (via SSM Session Manager)
