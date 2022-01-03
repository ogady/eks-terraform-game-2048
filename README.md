# eks-terraform-sample

## AWSリソース構築

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
aws --profile ${aws-profile} eks --region ap-northeast-1 update-kubeconfig --name eks-example
```

## kube-prometheusインストール

```sh
helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts

helm repo add stable https://charts.helm.sh/stable

helm repo update

helm install example prometheus-community/kube-prometheus-stack \
    -n monitoring \
    --create-namespace

# prometheusのGUI表示
# username:admin
# password:prom-operator
kubectl port-forward svc/example-grafana -n monitoring 3000:80
open http://127.0.0.1:3000
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
  --set clusterName=ogady-eks-example \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  -n kube-system

# targetgroupbindingリソース作成
TARGET_GROUP_ARN=${ALBターゲットグループARN} \
SECURITY_GROUP_ID=${ALBセキュリティグループID} \
envsubst < manifests/alb_controller/targetgroupbinding.yaml | \
kubectl apply -f -
```
