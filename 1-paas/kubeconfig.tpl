apiVersion: v1
kind: Config
preferences: {}

clusters:
- name: ${cluster_name}
  cluster:
    server: ${cluster_endpoint}
    certificate-authority-data: ${cluster_ca}

contexts:
- name: ${cluster_name}
  context:
    cluster: ${cluster_name}
    user: ${cluster_name}-admin

current-context: ${cluster_name}

users:
- name: ${cluster_name}-admin
  user:
    client-certificate-data: ${cluster_token}
    client-key-data: ${cluster_key}
