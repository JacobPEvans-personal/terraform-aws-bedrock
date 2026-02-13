terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "2.3.2"
    }
  }
}

# Dummy provider - required by bedrock module but not used when create_default_kb = false
provider "opensearch" {
  url = "https://localhost:9200"
}
