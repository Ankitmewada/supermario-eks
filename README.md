# 🎮 Super Mario Game Deployment on AWS EKS
### AWS DevOps Project — Step by Step Guide

---

## 📋 Prerequisites
- AWS Account (login as **IAM User**, NOT root)
- IAM User with **Administrator Access** policy
- Access Key & Secret Key ready
- Region: **us-east-1 (N. Virginia)** throughout the entire project

---

## ⚡ Quick Reference — Correct Order
1. Create S3 Bucket
2. Delete `us-east-1e` subnet
3. Launch EC2
4. Install all tools
5. Create IAM Role → Attach to EC2
6. Clone repo → Edit config files
7. Run Terraform
8. Deploy Mario
9. Access via browser
10. Cleanup

---

## STEP 1 — Create S3 Bucket (Do This FIRST)

> The S3 bucket stores Terraform state. Create it before anything else.

1. Go to **AWS Console → S3 → Create bucket**
2. Give it a **unique name** (e.g. `supermario-terraform-yourname-123`)
3. Region: **us-east-1**
4. Keep everything else default
5. Click **Create bucket**

> ⚠️ Note down the bucket name — you'll need it later in `backend.tf`

---

## STEP 2 — Delete `us-east-1e` Subnet

> EKS does not support `us-east-1e` availability zone. Terraform will fail if this subnet exists.

1. Go to **AWS Console → VPC → Subnets**
2. Make sure region is **us-east-1** (top right)
3. Find the subnet with Availability Zone **`us-east-1e`**
4. Select it → **Actions → Delete subnet** → Confirm

---

## STEP 3 — Launch EC2 Instance

> This is your working machine where you will run all commands.

1. Go to **AWS Console → EC2 → Launch Instance**
2. Settings:
   - **AMI**: Ubuntu
   - **Instance Type**: `c7i-flex.large`
   - **Key Pair**: Create new or use existing
   - **Security Group**: Allow All Traffic (inbound)
3. Click **Launch Instance**
4. Wait for status to show **Running**
5. Select instance → Click **Connect → EC2 Instance Connect → Connect**

---

## STEP 4 — Install All Required Tools

> Run these commands one by one inside your EC2 machine.

### Switch to root and update
```bash
sudo su
apt update
```

### Install Docker
```bash
apt install docker.io -y
usermod -aG docker ubuntu
newgrp docker
```

### Install Terraform
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform -y
```

### Install AWS CLI
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install
```

### Install kubectl
```bash
sudo apt install curl -y
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Configure AWS CLI
```bash
aws configure
```
> Enter your **Access Key**, **Secret Key**, region: `us-east-1`, output: `json`

---

## STEP 5 — Create IAM Role and Attach to EC2

> This allows your EC2 machine to interact with AWS services like EKS, S3 etc.

### Create the Role:
1. Go to **AWS Console → IAM → Roles → Create Role**
2. Select **EC2** as trusted entity
3. Attach policy: **AdministratorAccess**
4. Give it a name (e.g. `supermario-project-role`)
5. Click **Create Role**

### Attach Role to EC2:
1. Go to **EC2 → Instances**
2. Select your EC2 machine
3. **Right click → Security → Modify IAM Role**
4. Select the role you just created
5. Click **Update IAM Role**

---

## STEP 6 — Clone Repository and Configure Files

### Clone the repo
```bash
mkdir supermario
cd supermario
git clone https://github.com/akshu20791/supermario-game
cd supermario-game/EKS-TF
```

### Edit backend.tf
```bash
vim backend.tf
```
Update it with your S3 bucket name and region:
```hcl
terraform {
  backend "s3" {
    bucket = "YOUR-S3-BUCKET-NAME"    # ← your bucket name here
    region = "us-east-1"
    key    = "terraform.tfstate"
  }
}
```
Save and exit: `:wq`

### Edit main.tf — Fix Instance Type and Scaling

> ⚠️ IMPORTANT: Default instance type in the file won't work. Must change to t3.micro.

```bash
vim main.tf
```

Find the node group section and change:
```hcl
instance_types = ["t3.micro"]

scaling_config {
  desired_size = 1
  max_size     = 1
  min_size     = 1
}
```
Save and exit: `:wq`

### Edit deployment.yaml — Fix Replicas

```bash
cd ..
vim deployment.yaml
```

Find and change replicas:
```yaml
replicas: 1
```
Save and exit: `:wq`

---

## STEP 7 — Run Terraform to Build Infrastructure

> Terraform will automatically create the EKS cluster, node group, VPC, and all required AWS resources. This takes 10-15 minutes.

```bash
cd EKS-TF

terraform init

terraform validate

terraform plan

terraform apply --auto-approve
```

> ⏳ Wait for **"Apply complete!"** message. Do NOT press Ctrl+C.

---

## STEP 8 — Connect to EKS Cluster

> After Terraform completes, configure kubectl to talk to your EKS cluster.

```bash
aws eks update-kubeconfig --name EKS_CLOUD --region us-east-1
```

---

## STEP 9 — Deploy Mario App

```bash
cd /home/ubuntu/supermario/supermario-game

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

kubectl get all
```

### Fix if Pods are Pending — Scale Down CoreDNS

> t3.micro has limited pod capacity. System pods take up space. Scale down CoreDNS to free up a slot for Mario.

```bash
kubectl scale deployment coredns --replicas=1 -n kube-system
```

Check pods again:
```bash
kubectl get pods
```
Wait for Mario pod to show `1/1 Running`

---

## STEP 10 — Get Load Balancer URL and Access Game

```bash
kubectl describe service mario-service
```

Look for **LoadBalancer Ingress** line — copy that URL.

Open in browser:
```
http://PASTE-YOUR-URL-HERE
```

> ⚠️ Must be **http://** NOT https://
> Wait 3-5 minutes if it doesn't open immediately (Load Balancer is provisioning)

### If Still Not Opening — Check Security Group
1. Go to **EC2 → Load Balancers** → click your LB
2. **Security tab** → Edit inbound rules
3. Add: Type **HTTP**, Port **80**, Source **0.0.0.0/0**
4. Also do the same for the **EKS worker node** security group

---

## 🧹 STEP 11 — Cleanup (After Assessment)

> Always destroy everything to avoid AWS charges!

```bash
cd /home/ubuntu/supermario/supermario-game/EKS-TF
terraform destroy --auto-approve
```

Wait for **"Destroy complete!"**

Then manually delete:
- **EC2**: Terminate your instance
- **S3**: Empty bucket first → then delete bucket
- **IAM**: Delete your project roles
- **EKS**: Verify no clusters remain

---

## ❌ Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `UnsupportedAvailabilityZoneException us-east-1e` | Subnet in unsupported AZ exists | Delete `us-east-1e` subnet from VPC console |
| `EntityAlreadyExists: Role already exists` | Old IAM roles not cleaned up | Delete old roles from IAM console |
| `InvalidParameterCombination - not eligible for Free Tier` | Wrong instance type | Change to `t3.micro` in `main.tf` |
| `0/1 nodes available: Too many pods` | Node is full with system pods | Run `kubectl scale deployment coredns --replicas=1 -n kube-system` |
| `No changes. 0 destroyed` on terraform destroy | Wrong directory | Always run from `EKS-TF` folder |
| Region mismatch errors | Wrong region in .tf files | Ensure all `.tf` files use `us-east-1` |
| Browser not opening | Security group blocking port 80 | Add HTTP port 80 rule to LB and node security groups |

---

## 📁 Important File Locations

```
supermario/
└── supermario-game/
    ├── deployment.yaml     ← set replicas: 1
    ├── service.yaml
    └── EKS-TF/
        ├── main.tf         ← set instance_types: t3.micro, desired_size: 1
        └── backend.tf      ← set your S3 bucket name and region
```

---

## 🖥️ Instance Types Summary

| Machine | Instance Type | Purpose |
|---------|--------------|---------|
| Your EC2 (working machine) | `c7i-flex.large` | Where you type all commands |
| EKS Node (auto created by Terraform) | `t3.micro` | Where Mario app actually runs |

---

## ✅ Final Checklist Before Starting

- [ ] Logged in as IAM user (not root)
- [ ] Region set to us-east-1
- [ ] S3 bucket created
- [ ] `us-east-1e` subnet deleted
- [ ] Access Key & Secret Key ready for `aws configure`

---

*Good luck with your Wipro Assessment! 🚀🎮*
