data "aws_region" "current" {}

resource "random_string" "rand" {
    length = 24
    specical = false
    upper   = false
}

locals {
    namespace = substr(join("-", [var.namespace, random_string.rand.result]),0,24)
}

resource "aws_resourcegroups_group" "resourcegroups_group" {
    name = "${local.namespace}-group"

    resource_query {
        query = <<-JSON
        {
            "ResouceTypeFilters": [
                "AWS:AllSupported"
            ],
            "TagFilters": [{
                "Key" : "ResourceGroup",
                "Value": ["${local.namespace}"]
            }
            ]
        }
        JSON
    }
}

resource "aws_kms_key" "kms_key" {
    tags = {
        ResourceGroup = local.namespace
    }
}

resource "aws_s3_bucket" "s3_bucket" {
    bucket  = "${local.namespace}-state-bucket"
    force_destory = var.force_destory_state

    versioning {
        enable = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "aws:kms"
                kms_master_key_id = aws_kms_key.kms_key.arn
            }
        }
    }

    tags = {
        ResourceGroup  = local.namespace
    }
}

resource "aws_s3_bucket_public_access_block" "s3_bucket" {
    bucket = aws_s3_bucket.s3_bucket.id
    block_public_acls  = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_dynamodb_table" "dynamodb_table" {
    name = "${local.namespace}-state-lock"
    hash_key = "LockID"
    billing_mode = "PAY_PER_REQUEST"
    attribute = {
        name = "LockID"
        type = "S
    }
    tags = {
        ResourceGroup = local.namespace
    }
}
