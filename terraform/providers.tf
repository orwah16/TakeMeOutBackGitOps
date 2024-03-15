terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
}

# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }

resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "3.35.4"

  values = [file("values/argocd.yaml")]

}
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.EKS.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.EKS.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", "terraform-eks-cluster"]
      command     = "aws"
    }
  }
}