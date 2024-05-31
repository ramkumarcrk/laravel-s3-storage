provider "aws" {
  region = "us-east-1"
  # You can also specify other configuration options like access key and secret key if needed
}

variable "group_names" {
  description = "The unique group names for the IAM groups"
  type        = list(string)
}

variable "user_names" {
  description = "The user names to be added to the IAM groups"
  type        = list(string)
}

variable "s3_bucket_names" {
  description = "The unique names for the S3 buckets"
  type        = list(string)
}

variable "user_group_map" {
  description = "A map of users to groups"
  type        = map(list(string))
  default     = {}
}

locals {
  s3_policy_template = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1692807537432",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::%s",
        "arn:aws:s3:::%s/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_group" "s3_full_access_group" {
  for_each = toset(var.group_names)
  name     = each.value
}

resource "aws_iam_policy_attachment" "s3_full_access_attachment" {
  for_each = toset(var.group_names)
  name       = "s3_full_access_attachment_${each.key}"
  groups     = [aws_iam_group.s3_full_access_group[each.key].name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_user" "user" {
  for_each = toset(var.user_names)
  name     = each.value
}

resource "aws_iam_user_group_membership" "group_membership" {
  for_each = var.user_group_map
  user     = each.key
  groups   = [for group in each.value : aws_iam_group.s3_full_access_group[group].name]
}

resource "aws_iam_access_key" "access_key" {
  for_each = toset(var.user_names)
  user     = aws_iam_user.user[each.key].name
}

resource "aws_s3_bucket" "storage_bucket" {
  for_each = toset(var.s3_bucket_names)
  bucket   = each.value
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "public_allow" {
  for_each = toset(var.s3_bucket_names)
  bucket = aws_s3_bucket.storage_bucket[each.key].id
  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "ownership_controls" {
  for_each = toset(var.s3_bucket_names)
  bucket = aws_s3_bucket.storage_bucket[each.key].id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  for_each = toset(var.s3_bucket_names)
  bucket = aws_s3_bucket.storage_bucket[each.key].id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  for_each = toset(var.s3_bucket_names)
  bucket = aws_s3_bucket.storage_bucket[each.key].id

  policy = format(local.s3_policy_template, each.value, each.value)
}

resource "aws_s3_bucket_acl" "acl_storage_bucket" {
  for_each = toset(var.s3_bucket_names)
  bucket   = aws_s3_bucket.storage_bucket[each.key].id
  acl      = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.ownership_controls]

}

resource "aws_s3_bucket_cors_configuration" "cors_storage_bucket" {
  for_each = toset(var.s3_bucket_names)
  bucket = aws_s3_bucket.storage_bucket[each.key].id

  cors_rule {
    allowed_headers = []
    allowed_methods = ["PUT", "POST", "GET", "DELETE"]
    allowed_origins = ["*"]
  }
}

output "s3_bucket_paths" {
  value = { for bucket in aws_s3_bucket.storage_bucket : bucket.bucket => bucket.bucket_domain_name }
}

output "user_credentials" {
  sensitive = true
  value = { for user in aws_iam_user.user :
    user.name => {
      access_key_id     = aws_iam_access_key.access_key[user.name].id
      secret_access_key = aws_iam_access_key.access_key[user.name].secret
    }
  }
}