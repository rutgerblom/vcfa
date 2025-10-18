terraform {
  required_version = ">= 1.13.0, < 2.0.0"
  
  required_providers {
    vcfa = {
      source  = "vmware/vcfa"
      version = "~> 1.0.0"
    }
  }
}