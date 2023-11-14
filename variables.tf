variable "bucket_name" {
  type        = string
  description = "The name of the bucket."
}

variable "bucket_acl" {
  type        = string
  description = "The ACL applied to the S3 bucket."
  default     = "private"
}

variable "versioning" {
  description = "A boolean that indicates if versioning should be enabled."
  type        = bool
  default     = false
}

variable "sse_algorithm" {
  type        = string
  description = "The server-side encryption algorithm to use (e.g., AES256, aws:kms)."
  default     = "AES256"
}

variable "tags" {
  description = "A map of tags to assign to the bucket."
  type        = map(string)
  default     = {}
}

variable "block_public_acls" {
  type        = bool
  description = "Block public ACLs for this bucket."
  default     = true
}

variable "block_public_policy" {
  type        = bool
  description = "Block public bucket policies for this bucket."
  default     = true
}

variable "ignore_public_acls" {
  type        = bool
  description = "Ignore public ACLs for this bucket."
  default     = true
}

variable "restrict_public_buckets" {
  type        = bool
  description = "Restrict public bucket policies for this bucket."
  default     = true
}

variable "policy_actions" {
  description = "List of actions the policy should apply to."
  type        = list(string)
  default     = ["s3:GetObject"]
}

variable "policy_principals" {
  description = "List of principal AWS accounts or services which are allowed to access the bucket."
  type        = list(string)
  default     = ["*"] # Be careful with the wildcard; it allows public access.
}

variable "policy_prefixes" {
  description = "List of object prefixes this policy applies to."
  type        = list(string)
  default     = [""]
}
