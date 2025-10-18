# Configure the VMware Cloud Foundation Automation Provider
provider "vcfa" {
  auth_type             = "api_token"
  api_token             = var.vcfa_api_token
  org                   = var.vcfa_organization
  url                   = var.vcfa_url
  allow_unverified_ssl  = var.vcfa_allow_unverified_ssl
  logging               = true # Enables logging
  logging_file          = "vcfa.log"
}
