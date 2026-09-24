Add profile for cluster creation export AWS_PROFILE=Pooja
aws sts get-caller-identity
aws eks list-clusters aws eks update-kubeconfig --region us-east-1 --name prod-eks-cluster
Test cluster deployed
# Query the app endpoint using cURL
curl -I http://$(kubectl get svc production-app-service -n sample-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
