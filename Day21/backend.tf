terraform {
  cloud {
    organization = "myOrganization144"

    workspaces {
      name = "day21-dev"
    }
  }
}