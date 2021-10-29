variable "location" {
  default = "westus2"
}

variable "base-name" {
  default = "azure-auto-scaler"
}

locals {
  basename = replace(var.base-name, "-", "")
}
