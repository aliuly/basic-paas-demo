
* [x] Domain names
  * mern2-dev.cassiopeia.public.t-cloud.com
  * mern2.cassiopeia.public.t-cloud.com
  * Commands
    ```bash
    name=mern2-dev
    # name=mern2
    certbot \
	certonly \
	-d "$name.cassiopeia.public.t-cloud.com" \
	-m "tee6efoh@yopmail.com" \
	--preferred-challenges dns \
	--manual \
	--manual-auth-hook "tcloudpublic-cerbot-helper.sh auth" \
	--manual-cleanup-hook "tcloudpublic-cerbot-helper.sh clean" \
	--agree-tos --no-eff-email \
	-n
    ```
* [x] Add NAT gateway to modules/network
* [x] Add bastion host
* [x] Create a VPN module
* [x] tidy script
* [x] Create key_pair
    ```hcl
    key_name = opentelekomcloud_compute_keypair_v2.sshkey.name

    resource "opentelekomcloud_compute_keypair_v2" "sshkey" {
      name       = "key-wordpress-asg"
      public_key = var.cloud_user.ssh_keys[0]
    }
    ```
- CCE:  master (cce.s1.small|cce.s2.small)
- DDS:  Single mode, 20 GB, 3-day backup
- App:  1 replica each for api and ui
- Auth: 1 oauth2-proxy replica
- WAF:  1 dedicated instance, rate limit 100 req/s/IP
- TLS:  Let's Encrypt -> WAF; self-signed -> Ingress (WAF->ELB)
- Istio: STRICT mTLS in mern namespace; istiod built-in CA
