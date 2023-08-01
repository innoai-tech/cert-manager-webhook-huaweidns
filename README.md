# Cert Manager Webhook Huawei DNS

## Install

```shell
# install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

# install cert-manager-webhook-huaweidns
kubectl apply -f https://github.com/innoai-tech/cert-manager-webhook-huaweidns/releases/download/latest/cert-manager-webhook-huaweidns.yaml
```

## Settings

华为云控制台 -> 统一身份认证 -> 创建权限

```json
{
  "Version": "1.1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dns:recordset:list",
        "dns:recordset:create",
        "dns:recordset:delete"
      ]
    }
  ]
}
```

分配到账户，并创建 token

## Manifests

### ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <email>
    preferredChain: ''
    privateKeySecretRef:
      name: letsencrypt-prod
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
      - dns01:
          webhook:
            config:
              appKey: <appKey>
              appSecret: <appSecret>
              region: <region>  # 域名所在 region
              zoneId: <zoneId>  # 域名 zoneId
            groupName: acme.innoai.tech
            solverName: huawei-dns
```

### Wildcard Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: staging-wildcard
  namespace: cert-manager
spec:
  dnsNames:
    - '*.staging.x.io'
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt-prod
  secretName: staging-wildcard
  usages:
    - digital signature
    - key encipherment
```

* TLS with contour https://projectcontour.io/docs/1.25/config/tls-delegation/