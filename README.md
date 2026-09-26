Add profile for cluster creation export AWS_PROFILE=Pooja
aws sts get-caller-identity
aws eks list-clusters 
aws eks update-kubeconfig --region us-east-1 --name prod-eks-cluster
Test cluster deployed
# Query the app endpoint using cURL
curl -I http://$(kubectl get svc production-app-service -n sample-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# --- IAM REUSE CONFIGURATION ---
      create_iam_role = false
      iam_role_arn    = module.eks.eks_managed_node_groups["general"].iam_role_arn
      ++++++++++++++++
      EKS BACKUP
      VELERO_POD=$(kubectl get pods -n velero -l app.kubernetes.io/name=velero -o jsonpath='{.items[0].metadata.name}')
      kubectl exec -n velero -it $VELERO_POD -- /velero backup create test-app-backup   --include-namespaces sample-app   --wait
      velero backup create test-app-backup2 --include-namespaces sample-app --waitq
      velero backup describe test-app-backup1
      kubectl delete namespace sample-app
      kubectl get pods -n sample-app
      velero restore create sample-app-restore-1 --from-backup test-app-backup1 --wait
      velero restore describe sample-app-restore-1
      kubectl get pods -n sample-app
      Restore to new namespace 
      ++++++++++++++++++++++++++
      velero restore create sample-app-dr-restore --from-backup test-app-backup1 --namespace-mappings sample-app:sample-app-dr --wait