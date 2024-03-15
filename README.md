# GITOPS repository for the TakeMeOutBack project 
Backend repository: https://github.com/orwah16/TakeMeOutBack
Frontend repository: https://github.com/orwah16/TakeMeOut
 The project was deployed to an EKS cluster on two private subenets with another 2 public subnets for bastions and Nat
 The infrastructure was provisioned using terraform and deployed using Argocd and Helm, the deployment is triggered using 
 the CI pipeline on TakeMeOutBack repository with every merge from the feature branch
 Traffic gets to the cluster using loadbalancer
 Number of hosts is managed using auto-scaler
 for networking the project utilizes CNI plugin and for storage management CSI plugin
 Monitoring:
 for metric scraping prometheus was used with grafana for building dashboards (grafana was deployed using helm terraform provider charts)
![alt text](./Images/terraform.png?raw=true)
![alt text](./Images/argocd.png?raw=true)
![alt text](./Images/prometheus.png?raw=true)
![alt text](./Images/grafana.png?raw=true)
