variable "POSTGRES_DB_NAME" {
  description = "PostgreSQL db name"
  type        = string
}

variable "POSTGRES_USERNAME" {
  description = "User for the PostgreSQL"
  type        = string
}

variable "POSTGRES_PASSWORD" {
  description = "Password for the PostgreSQL user"
  type        = string
}

variable "AWS_REGION" {
  description = "aws region"
  type        = string
}
