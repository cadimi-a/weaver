variable "project_id" {
  type = string
}

variable "infra_name_tag" {
  type = string
}

variable "region" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "developer_ip" {
  type = string
}

variable "node_machine_type" {
  type = string
}
