module "vpc" {
  source = "../../modules/vpc"

  environment          = "prod"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "prod"
    Project     = "my-app"
  }
}

module "s3" {
  source = "../../modules/s3"

  environment      = "prod"
  bucket_name      = "my-app-prod-bucket-${random_id.bucket_suffix.hex}"
  versioning_enabled = true

  lifecycle_rules = [
    {
      id      = "archive-to-glacier"
      enabled = true
      transitions = [
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      expiration_days = null
    }
  ]

  tags = {
    Environment = "prod"
    Project     = "my-app"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  environment    = "prod"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  instance_count = 2
  instance_type  = "t3.large"

  tags = {
    Environment = "prod"
    Project     = "my-app"
  }
}

module "eks_fargate" {
  source = "../../modules/eks-fargate"

  environment = "prod"
  subnet_ids  = module.vpc.private_subnet_ids

  fargate_profiles = {
    kube-system = {
      namespace = "kube-system"
      labels    = null
    }
    default = {
      namespace = "default"
      labels    = null
    }
    app = {
      namespace = "app"
      labels = {
        Environment = "prod"
      }
    }
  }

  tags = {
    Environment = "prod"
    Project     = "my-app"
  }
}

module "route53" {
  source = "../../modules/route53"

  environment = "prod"
  zone_name   = "myapp.com"
  create_zone = true

  records = [
    {
      name    = "api.myapp.com"
      type    = "A"
      ttl     = 300
      records = module.ec2.instance_private_ips
      alias   = null
    },
    {
      name    = "app.myapp.com"
      type    = "CNAME"
      ttl     = 300
      records = ["${module.eks_fargate.cluster_endpoint}"]
      alias   = null
    }
  ]

  tags = {
    Environment = "prod"
    Project     = "my-app"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}
