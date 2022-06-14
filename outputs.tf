output "s3_static_bucket_arn" {
  description = "s3 bucket that holds static assets (e.g. videos, thumbnails, ...)"
  value       = module.cdn_content.s3_bucket_arn
}
