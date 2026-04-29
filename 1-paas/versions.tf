
terraform {
  required_version = ">= 1.7"

  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = "~> 1.36"
    }
  }
  backend "s3" { }

}

provider "opentelekomcloud" {}
