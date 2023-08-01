package webhook

import (
	kubepkgspec "github.com/octohelm/kubepkg/cuepkg/kubepkg"
)

#Webhook: {
	#values: {
		// api-group
		groupName: string | *"acme.innoai.tech"

		certManager: {
			namespace:          string | *"cert-manager"
			serviceAccountName: string | *"cert-manager"
		}
	}

	kubepkgspec.#KubePkg & {
		metadata: {
			name:      _ | *"cert-manager-webhook-huaweidns"
			namespace: _ | *"cert-manager"
		}

		spec: {
			version: _ | *"v0.0.0"

			deploy: {
				kind: "Deployment"
				spec: replicas: 1
			}

			services: "#": ports: containers."webhook".ports

			containers: webhook: {
				image: {
					name: _ | *"ghcr.io/innoai-tech/cert-manager-webhook-huaweidns"
					tag:  _ | *"\(spec.version)"
				}

				args: [
					"--tls-cert-file=/tls/tls.crt",
					"--tls-private-key-file=/tls/tls.key",
				]

				env: GROUP_NAME: "\(#values.groupName)"

				ports: https: 443

				readinessProbe: kubepkgspec.#Probe & {
					httpGet: {
						path:   "/healthz"
						scheme: "HTTPS"
						port:   ports.https
					}
				}

				livenessProbe: readinessProbe
			}

			volumes: "webhook-tls": {
				type:      "Secret"
				mountPath: "/tls"
				spec: data: {
					//					"tls.crt": ""
					//					"tls.key": ""
				}
			}

			manifests: {
				apiService: {
					apiVersion: "apiregistration.k8s.io/v1"
					kind:       "APIService"
					"metadata": {
						name: "v1alpha1.\(#values.groupName)"
						annotations: "cert-manager.io/inject-ca-from": "\(metadata.namespace)/\(manifests.servingCertificate.metadata.name)"
					}
					spec: {
						group:                "\(#values.groupName)"
						groupPriorityMinimum: 1000
						versionPriority:      15
						service: {
							name:      "\(metadata.name)"
							namespace: "\(metadata.namespace)"
						}
						version: "v1alpha1"
					}
				}
				isser: {
					apiVersion: "cert-manager.io/v1"
					kind:       "Issuer"
					"metadata": name: "\(metadata.name)-selfsign"
					spec: selfSigned: {}
				}
				ca: {
					apiVersion: "cert-manager.io/v1"
					kind:       "Certificate"
					"metadata": name: "\(metadata.name)-ca"
					spec: {
						secretName: "\(metadata.name)-ca"
						duration:   "43800h"
						issuerRef: name: manifests.isser.metadata.name
						commonName: "ca.\(metadata.name).cert-manager"
						isCA:       true
					}
				}

				caIssuer: {
					apiVersion: "cert-manager.io/v1"
					kind:       "Issuer"
					"metadata": name: "\(metadata.name)-ca"
					spec: ca: secretName: manifests.ca.metadata.name
				}

				servingCertificate: {
					apiVersion: "cert-manager.io/v1"
					kind:       "Certificate"
					"metadata": name: "\(metadata.name)-webhook-tls"
					spec: {
						secretName: "\(metadata.name)-webhook-tls"
						duration:   "8760h"
						issuerRef: name: manifests.caIssuer.metadata.name
						dnsNames: [
							"\(metadata.name)",
							"\(metadata.name).\(metadata.namespace)",
							"\(metadata.name).\(metadata.namespace).svc",
						]
					}
				}

				roleBinding: {
					apiVersion: "rbac.authorization.k8s.io/v1"
					kind:       "ClusterRoleBinding"
					"metadata": name: "\(metadata.name)-binding-for-centry"

					roleRef: {
						apiGroup: "rbac.authorization.k8s.io"
						kind:     "ClusterRole"
						name:     "\(metadata.name)"
					}

					subjects: [
						{
							apiGroup:  ""
							kind:      "ServiceAccount"
							name:      #values.certManager.serviceAccountName
							namespace: #values.certManager.namespace
						},
					]
				}
			}

			serviceAccount: kubepkgspec.#ServiceAccount & {
				scope: "Cluster"
				rules: [
					{
						apiGroups: [
							"\(#values.groupName)",
						]
						resources: ["*"]
						verbs: ["create"]
					},
					// extension-apiserver-authentication-reader.kube-system.Role
					{
						verbs: ["get", "list", "watch"]
						apiGroups: [""]
						resources: ["configmaps"]
						resourceNames: ["extension-apiserver-authentication"]
					},
					// "system:auth-delegator",
					{
						verbs: ["create"]
						apiGroups: [ "authorization.k8s.io"]
						resources: [ "subjectaccessreviews", "tokenreviews"]
					},
				]
			}
		}
	}
}
