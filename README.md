# eks-terraform-sample

- ref:https://github.com/kubernetes-sigs/aws-load-balancer-controller
- game-2048:https://hub.docker.com/r/alexwhen/docker-2048

## AWSリソース構築

**以下のvariableのcreatorを任意のものに変更する**
- terraform/app/variable.tf
- terraform/network/variable.tf

```sh
# network構築
cd ./terraform/network
terraform apply

# eks構築
cd ./terraform/app
terraform apply
```

## kubectl用のコンフィグ取得

```sh
aws --profile ${aws-profile} eks --region ap-northeast-1 update-kubeconfig --name ${クラスタ名}
```

## AWS Application Load Balancer Controller

```sh
# サービスアカウント作成
ROLE_ARN=${ロールARN} \
envsubst < manifests/alb_controller/aws-load-balancer-controller-service-account.yaml | \
kubectl apply -f -

# TargetGroupBindingのCRDをデプロイ
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# ingress controllerのdeploy
helm repo add eks https://aws.github.io/eks-charts

helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=${クラスター名} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system

# targetgroupbindingリソース作成
TARGET_GROUP_ARN=${ALBターゲットグループARN} \
SECURITY_GROUP_ID=${ALBセキュリティグループID} \
envsubst < manifests/alb_controller/targetgroupbinding.yaml | \
kubectl apply -f -
```
