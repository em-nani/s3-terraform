provider "aws" {
  version = "~> 4.0"
  region = var.region
}

resource "aws_s3_bucket" "install" {
    bucket_prefix = var.bucket_prefix
    acl = "public-read"

    website {
      index_document = "index.html"
      error_document = "error.html"
    }
  
}

resource "aws_s3_bucket_website_configuration" "install" {
  bucket = aws_s3_bucket.install.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
}

resource "aws_s3_bucket_policy" "install" {
  bucket = aws_s3_bucket.install.id

policy = <<POLICY
{
     "Version": "2012-10-17",    
    "Statement": [        
      {            
          "Sid": "PublicReadGetObject",            
          "Effect": "Allow",            
          "Principal": "*",            
          "Action": [                
             "s3:GetObject"            
          ],            
          "Resource": [
             "arn:aws:s3:::${aws_s3_bucket.install.id}/*"            
          ]        
      }    
    ]
}
POLICY
}

locals {
  s3_origin_id = "install"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    origin {
      domain_name = "${aws_s3_bucket.install.bucket_regional_domain_name}"
      origin_id = "${local.s3_origin_id}"

      # s3_origin_config {
      #   origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
      # }
    }

    enabled = true
    is_ipv6_enabled = true
    comment = "Some comment"
    default_root_object = "index.html"

    # logging_config {
    #    include_cookies = false
    #    bucket = "mylogs.s3.amazonaws.com"
    #    prefix = "myprefix"
    #}
    #aliases = []
    default_cache_behavior {
      allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = "${local.s3_origin_id}"

      forwarded_values {
        query_string = false

        cookies {
            forward = "none"
        }
      }
      min_ttl = 0
      default_ttl = 86400
      max_ttl = 31536000
      compress = true
      viewer_protocol_policy = "redirect-to-https"
    }
    # Cache beavior with precedence
    ordered_cache_behavior {
      path_pattern = "/content/*"
      allowed_methods = ["GET","HEAD", "OPTIONS"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = "${local.s3_origin_id}"
      forwarded_values {
        query_string = false

        cookies {
          forward = "none"
        }
      }
      min_ttl = 0
      default_ttl = 3600
      max_ttl = 86400
      compress = true
      viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

restrictions {
    geo_restriction {
        restriction_type = "whitelist"
        locations = ["US", "CA", "GB", "DE", "PT", "IN"]
    }
}

  tags = {
   "Environment" = "dev"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
