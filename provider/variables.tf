# VMware Cloud Foundation Automation (VCFA) provider variables

variable "vcfa_url" {
  type        = string
  description = "The base URL for the VCFA API (e.g. https://.lab.local)"
}

variable "vcfa_api_token" {
  type        = string
  description = "API Token"
  sensitive   = true
}

variable "vcfa_organization" {
  type        = string
  description = "VCFA Organization"
}

variable "vcfa_allow_unverified_ssl" {
  type        = bool
  description = "Whether to allow unverified SSL certificates (true for lab environments)"
  default     = true
}
