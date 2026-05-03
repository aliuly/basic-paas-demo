This folder holds a small sample CCE deployment on T Cloud Public.

It assumes connectivity to an On Prem network via a VPN.  The On
Prem network host an IdP based on authentik and client systems.

Folders

* 1-infra \
  Deploys infrastructure through Open Tofu.  Used to deploy all
  native T Cloud Public resources.
* 2-shared \
  Deploys / configure Kubernetes infrastructure that is used to host
  the workloads.  Functionality like grafana reporting and http to
  https redirectors are deployed from here.  Deployment is done via
  Helm Charts and Kubectl
* 3-workloads \
  Deployment via Helm Charts and Kubectl of payload workloads.  Two
  sample applications are deployed, `helloworld` and `MERN demo`.
* scripts \
  Utility scripts.

