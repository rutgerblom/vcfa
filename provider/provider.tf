# Configure the VMware Cloud Foundation Automation Provider
provider "vcfa" {
  auth_type            = var.vcfa_auth_type
  user                 = var.vcfa_user
  password             = var.vcfa_password
  org                  = var.vcfa_organization
  url                  = var.vcfa_url
  allow_unverified_ssl = var.vcfa_allow_unverified_ssl
  logging              = var.vcfa_logging
  logging_file         = var.vcfa_log_file
}
