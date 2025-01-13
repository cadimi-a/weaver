variable "name_prefix" {
  description = "The name prefix of the resources"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "Map of subnet types to CIDR blocks"
  type = object({
    public = list(string)
    private = list(string)
    data = list(string)
  })
  default = {
    public = ["10.0.1.0/24", "10.0.2.0/24"]
    private = ["10.0.3.0/24", "10.0.4.0/24"]
    data = ["10.0.5.0/24", "10.0.6.0/24"]
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = false
}

variable "security_groups" {
  description = "Security groups to create as a list of objects"
  type = list(object({
    name = string
    inbound = list(object({
      from_port = number
      to_port   = number
      protocol  = string
      cidr_blocks = list(string)
      security_groups = list(string)
    }))
    outbound = list(object({
      from_port = number
      to_port   = number
      protocol  = string
      cidr_blocks = list(string)
      security_groups = list(string)
    }))
  }))
  default = [
    {
      name = "alb-sg"
      inbound = [
        {
          from_port = 443
          to_port   = 443
          protocol  = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
          security_groups = []
        }
      ]
      outbound = [
        {
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          security_groups = []
        }
      ]
    },
    {
      name = "server-sg"
      inbound = [
        {
          from_port = 80
          to_port   = 80
          protocol  = "tcp"
          cidr_blocks = []
          security_groups = ["alb-sg"]
        }
      ]
      outbound = [
        {
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          security_groups = []
        }
      ]
    },
    {
      name = "db-sg"
      inbound = [
        {
          from_port = 3306
          to_port   = 3306
          protocol  = "tcp"
          cidr_blocks = []
          security_groups = ["server-sg"]
        }
      ]
      outbound = [
        {
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          security_groups = []
        }
      ]
    },
    { # this setup is necessary in the case to use nat instance. error will occur if this is removed
      name = "allowing-internal-sg"
      inbound = [
        {
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["10.0.0.0/16"]
          security_groups = []
        }
      ]
      outbound = [
        {
          from_port = 0
          to_port   = 0
          protocol  = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          security_groups = []
        }
      ]
    }
  ]
}

variable "enable_nat_gateways" {
  description = "Enable NAT Gateways, or NAT Instance will be used"
  type        = bool
  default     = true
}

variable "nat_instance_type" {
  description = "NAT Instance type when NAT Gateways isn't used"
  type        = string
  default     = "t3.micro"
}

variable "vpc_endpoints" {
  description = "List of VPC endpoints to create. Each endpoint should specify its service name and type (gateway or interface)."
  type = list(object({
    service_name = string
    type         = string
  }))
  default = [
    {
      service_name = "com.amazonaws.us-east-1.s3"
      type         = "Gateway"
    },
    {
      service_name = "com.amazonaws.us-east-1.ssm"
      type         = "Interface"
    },
    {
      service_name = "com.amazonaws.us-east-1.ssmmessages"
      type         = "Interface"
    },
    {
      service_name = "com.amazonaws.us-east-1.ec2messages"
      type         = "Interface"
    }
  ]
}
