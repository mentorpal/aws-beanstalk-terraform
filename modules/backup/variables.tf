variable "name" {
  description = "backup plan name, should be unique"
  type        = string
}

variable "resources" {
  description = "A list of ARNs for resources to be backed up"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to apply to the backup plan, vaults etc"
  type        = map(any)
  default = {
    Project = "mentorpal"
    Source  = "terraform"
  }
}
