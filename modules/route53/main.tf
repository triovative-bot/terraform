resource "aws_route53_zone" "main" {
  count = var.create_zone ? 1 : 0

  name = var.zone_name

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

data "aws_route53_zone" "existing" {
  count = var.create_zone ? 0 : 1

  name         = var.zone_name
  private_zone = var.private_zone
}

resource "aws_route53_record" "records" {
  for_each = { for record in var.records : record.name => record }

  zone_id = var.create_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records

  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }
}
