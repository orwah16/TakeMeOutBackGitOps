resource "aws_iam_role" "node" {
  name = "terraform-eks-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.EKS.name
  node_group_name = "nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.EKS_private_subnet[*].id
  ami_type        = "AL2_x86_64"
  # instance_types = ["t3.micro"]
  #capacity_type  = "ON_DEMAND"
  # disk_size      = 20

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  # taint {
  #   key    = "team"
  #   value  = "dev"
  #   effect = "NO_SCHEDULE"
  # }

  launch_template {
    name    = aws_launch_template.eks_launch_template.name
    version = aws_launch_template.eks_launch_template.latest_version
  }



  depends_on = [
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-AmazonEC2ContainerRegistryReadOnly,
  ]
}


resource "aws_launch_template" "eks_launch_template" {
  name = "eks_launch_template"

  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  #image_id = data.aws_ami.server_ami.id
  #image_id      = "ami-03eaa1eb8976e21a9"
  instance_type = "t3a.medium"
  key_name = "bastionkey"
  # block_device_mappings {
  #   device_name = "/dev/xvda"
  #   ebs {
  #     volume_size = 5
  #     volume_type = "gp3"
  #   }
  # }
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "EKS-MANAGED-NODE"
      service       = "myapp"
      node-exporter = "true"
    }
  }

  user_data =  base64encode(<<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
#kubeproxy and coredns are installed automatically
UID=$(id -u)
if [ x$UID != x0 ] 
then
    #Beware of how you compose the command
    printf -v cmd_str '%q ' "$0" "$@"
    exec sudo su -c "$cmd_str"
fi

echo "starting bootstrap"

#create kubeconfig file
echo "creating kubeconfig file"
aws eks update-kubeconfig --name terraform-eks-cluster --region us-east-1

echo "installing kubectl"
#installing kubectl last stable version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl



--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"


echo "installing exporter"
#installing pormetheus exporter

useradd --system --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar -xvf node_exporter-1.5.0.linux-amd64.tar.gz
mv node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/

cat <<EOT >> /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOT

systemctl enable node_exporter
systemctl start node_exporter

# --==MYBOUNDARY==
# Content-Type: text/x-shellscript; charset="us-ascii"

# #increasing the max number of pods per node
# sudo /etc/eks/bootstrap.sh terraform-eks-cluster --use-max-pods false \ 
# --kubelet-extra-args '--max-pods=110'

--==MYBOUNDARY==--

EOF
)

}



 
