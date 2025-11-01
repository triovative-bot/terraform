module "vpc" {
  source = "../../modules/vpc"

  environment          = "dev"
  vpc_cidr            = "10.1.0.0/16"
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
  availability_zones  = ["us-east-1a", "us-east-1b"]

  tags = {
    Environment = "dev"
    Project     = "my-app"
  }
}

module "s3" {
  source = "../../modules/s3"

  environment      = "dev"
  bucket_name      = "my-app-dev-bucket-${random_id.bucket_suffix.hex}"
  versioning_enabled = false

  tags = {
    Environment = "dev"
    Project     = "my-app"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  environment    = "dev"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  instance_count = 1
  instance_type  = "t3.micro"

  tags = {
    Environment = "dev"
    Project     = "my-app"
  }
}

module "eks_fargate" {
  source = "../../modules/eks-fargate"

  environment = "dev"
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
        Environment = "dev"
      }
    }
  }

  tags = {
    Environment = "dev"
    Project     = "my-app"
  }
}

module "route53" {
  source = "../../modules/route53"

  environment = "dev"
  zone_name   = "dev.myapp.com"
  create_zone = true

  records = [
    {
      name    = "api.dev.myapp.com"
      type    = "A"
      ttl     = 300
      records = module.ec2.instance_private_ips
      alias   = null
    }
  ]

  tags = {
    Environment = "dev"
    Project     = "my-app"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}
