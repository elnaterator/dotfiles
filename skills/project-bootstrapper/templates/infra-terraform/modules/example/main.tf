# Example module. Rename/replace with real modules.
# Resources go here; consume var.environment for naming/tagging.

locals {
  name_prefix = "app-${var.environment}"
}
