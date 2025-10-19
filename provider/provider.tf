# Configure the VMware Cloud Foundation Automation Provider
provider "vcfa" {
  auth_type            = "integrated"
  user                 = "admin"
  password             = "VMware1!VMware1!"
  org                  = var.vcfa_organization
  url                  = var.vcfa_url
  allow_unverified_ssl = var.vcfa_allow_unverified_ssl
  logging              = false # Enables logging
  logging_file         = "vcfa.log"
}
