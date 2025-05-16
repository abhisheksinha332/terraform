variable "storage_account_name" {
  description = "The name of the storage account"
  type        = string
  
}

variable "blob_name" {
  description = "The name of the blob"
  type        = list(string)
}

variable "create_resource" {
  description = "Flag to create resources"
  type        = bool

}

variable "create_disk" {
  description = "Flag to create disk"
  type        = bool
}

variable "client_id" {
  description = "Client ID for the service principal"
  type        = string 
}

variable "client_secret" {
  description = "Client secret for the service principal"
  type        = string 
}

variable "tenant_id" {
  description = "Tenant ID for the service principal"
  type        = string  
}

variable "subscription_id" {
  description = "Subscription ID for the service principal"
  type        = string  
}

variable "access_Key" {
  description = "Access key for the storage account"
  type        = string  
}