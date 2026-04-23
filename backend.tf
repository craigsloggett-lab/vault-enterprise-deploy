terraform {
  cloud {
    organization = "craigsloggett-lab"

    workspaces {
      project = "Infrastructure"
      name    = "vault-enterprise-deploy"
    }
  }
}
