apiVersion: v1
kind: Config
preferences: {}

clusters:
- name: ${name}
  cluster:
    server: ${endpoint}
    certificate-authority-data: ${ca}

contexts:
- name: ${name}
  context:
    cluster: ${name}
    user: ${name}-admin

current-context: ${name}

users:
- name: ${name}-admin
  user:
    client-certificate-data: ${cert}
    client-key-data: ${key}
