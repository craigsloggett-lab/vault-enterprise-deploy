# Use the TF_TOKEN_app_terraform_io to set a User Token to authenticate with HCP Terraform.

terraform {
  cloud {
    organization = "craigsloggett-lab"

    workspaces {
      project = "Infrastructure"
      name    = "vault-enterprise-deploy"
    }
  }
}
