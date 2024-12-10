# Enable Artifact Registry API
resource "google_project_service" "project" {
  count = var.enable_api ? 1 : 0

  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

locals {
  member_and_role_per_repo = {
    for item in flatten([
      for repository_id, repository in var.repositories : concat([
        for reader in repository.readers : {
          "repository_id" : repository_id,
          "role" : "roles/artifactregistry.reader",
          "member" : reader,
        }
        ], [
        for writer in repository.writers : {
          "repository_id" : repository_id,
          "role" : "roles/artifactregistry.writer",
          "member" : writer,
        }
      ])
    ]) : "${item.repository_id}--${item.role}--${item.member}" =>
    {
      "repository_id" : item.repository_id,
      "role" : item.role,
      "member" : item.member,
    }
  }
}

resource "google_artifact_registry_repository" "repositories" {
  for_each = var.repositories

  project                = var.project_id
  repository_id          = each.key
  location               = each.value.location != "" ? each.value.location : var.default_location
  format                 = each.value.format
  description            = each.value.description
  cleanup_policy_dry_run = each.value.cleanup_policy_dry_run

  dynamic "cleanup_policies" {
    for_each = each.value.cleanup_policies != null ? each.value.cleanup_policies : {}

    content {
      id     = cleanup_policies.key
      action = cleanup_policies.value.action
      
      dynamic "most_recent_versions" {
        for_each = lookup(cleanup_policies.value, "most_recent_versions", {}) != {} ? [cleanup_policies.value.most_recent_versions] : []

        content {
          package_name_prefixes = most_recent_versions[0].package_name_prefixes
          keep_count            = most_recent_versions[0].keep_count
        }
      }

      dynamic "condition" {
        for_each = lookup(cleanup_policies.value, "condition", {}) != {} ? [cleanup_policies.value.condition] : []
        
        content {
          older_than   = lookup(condition.value, "older_than", null)
          tag_state    = lookup(condition.value, "tag_state", null)
          tag_prefixes = lookup(condition.value, "tag_prefixes", null)
        }
      }
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "member" {
  for_each = local.member_and_role_per_repo

  project    = var.project_id
  repository = google_artifact_registry_repository.repositories[each.value.repository_id].name
  location   = google_artifact_registry_repository.repositories[each.value.repository_id].location
  role       = each.value.role
  member     = each.value.member
}

# Create a custom role that allows the list of the Artifact Registry repositories
resource "google_project_iam_custom_role" "artifact_registry_lister" {
  count = length(var.artifact_registry_listers) > 0 ? 1 : 0

  project     = var.project_id
  role_id     = var.artifact_registry_listers_custom_role_name
  title       = "Artifact Registry Lister"
  description = "This role grants the ability to list repositories in Artifact Registry"
  permissions = ["artifactregistry.repositories.list"]
}

# Add the custom role to the group staff@sparkfabrik
resource "google_project_iam_binding" "artifact_registry_lister" {
  count = length(var.artifact_registry_listers) > 0 ? 1 : 0

  project = var.project_id
  role    = google_project_iam_custom_role.artifact_registry_lister[0].name
  members = var.artifact_registry_listers
}
