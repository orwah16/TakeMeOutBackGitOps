# GITOPS repository for the TakeMeOutBack project <br/>
<br/>
Backend repository: https://github.com/orwah16/TakeMeOutBack <br/>
Frontend repository: https://github.com/orwah16/TakeMeOut <br/>
<br/>
The project was deployed to an EKS cluster on two private subenets with another 2 public subnets for bastions and Nat <br/>
The infrastructure was provisioned using terraform and deployed using Argocd and Helm, the deployment is triggered using  <br/>
the CI pipeline on TakeMeOutBack repository with every merge from the feature branch <br/>
Traffic gets to the cluster using loadbalancer <br/>
Number of hosts is managed using auto-scaler <br/>
for networking the project utilizes CNI plugin and for storage management CSI plugin <br/>
### Monitoring: <br/>
for metric scraping prometheus was used with grafana for building dashboards (grafana was deployed using helm terraform provider charts) <br/>
![alt text](./Images/terraform.png?raw=true)
![alt text](./Images/argocd.png?raw=true)
![alt text](./Images/prometheus.png?raw=true)
![alt text](./Images/grafana.png?raw=true)
