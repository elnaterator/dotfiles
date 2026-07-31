# Native `terraform test` (Terraform 1.6+). Runs from the module dir: `terraform test`.
variables {
  environment = "dev"
}

run "name_prefix_includes_environment" {
  command = plan

  assert {
    condition     = output.name_prefix == "app-dev"
    error_message = "name_prefix must be app-<environment>"
  }
}
