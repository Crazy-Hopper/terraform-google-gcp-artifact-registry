variable "project_id" {
  type        = string
  description = "The GCP project ID that hosts the Artifact Registry."
}

variable "enable_api" {
  type        = bool
  description = "Whether to enable Artifact Registry API in the project. Useful if APIs are managed elsewhere."
  default     = true
}

# The default location used for the Artifact Registry repositories.
variable "default_location" {
  type        = string
  description = "The default location for the Artifact Registry repositories."
  default     = "europe-west1"
}

# Artifact Registry repositories.
variable "repositories" {
  type = map(object({
    description            = string
    format                 = optional(string, "DOCKER")
    readers                = optional(list(string), [])
    writers                = optional(list(string), [])
    location               = optional(string, "")
    cleanup_policy_dry_run = optional(bool, false)
  }))
  description = "List of Artifact Registry repositories to create."
}

variable "artifact_registry_listers_custom_role_name" {
  type        = string
  description = "Name of the custom role for Artifact Registry listers."
  default     = "custom.artifactRegistryLister"
}

variable "artifact_registry_listers" {
  type        = list(string)
  description = "List of principals that can list Artifact Registry repositories."
  default     = []
}
