# Bucket to store website

resource "google_storage_bucket" "website" {
  provider = google
  name = "example-website-bucket-by-gk"
  location = "ASIA-SOUTH1"
}


# Make new object public

resource "google_storage_object_access_control" "public_rule" {
  object = google_storage_bucket_object.static_site_src.name
  bucket = google_storage_bucket.website.name
  role = "READER"
  entity = "allUsers"
}

# Upload the html file to the bucket

resource "google_storage_bucket_object" "static_site_src" {
  name = "index.html"
  source = "../website/index.html"
  bucket = google_storage_bucket.website.name
}

# reserve a static external IP address

resource "google_compute_global_address" "website_ip" {
  provider = google
  name = "website-lb-ip"
}

# get the managed DNS Zone

resource "google_dns_managed_zone" "dns_zone" {
  provider = google
  name = "terraform-gcp"
  dns_name = "test.karthikeyan.cloud."
}

# add the IP to the DNS

resource "google_dns_record_set" "website" {
  provider = google
  name = google_dns_managed_zone.dns_zone.dns_name
  type = "A"
  ttl = 300
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas = [google_compute_global_address.website_ip.address]
}

# add the bucket as a CDN backend
resource "google_compute_backend_bucket" "website-backend" {
  provider = google
  name = "website-bucket"
  bucket_name = google_storage_bucket.website.name
  description = "Contains files needed for the website"
  enable_cdn = true
}

# GCP URL MAP
resource "google_compute_url_map" "website" {
  provider = google
  name = "website-url-map"
  default_service = google_compute_backend_bucket.website-backend.self_link
  host_rule {
    hosts = [ "*" ]
    path_matcher = "allpaths"
  }

    path_matcher {
      name = "allpaths"
      default_service = google_compute_backend_bucket.website-backend.self_link
    }
}


# GCP HTTP Proxy

resource "google_compute_target_http_proxy" "website" {
  provider = google
  name = "website-target-proxy"
  url_map = google_compute_url_map.website.self_link
}

# GCP forwarding rule

resource "google_compute_global_forwarding_rule" "default" {
  provider = google
  name = "website-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address = google_compute_global_address.website_ip.address
  ip_protocol = "TCP"
  port_range = "443"
  target = google_compute_target_http_proxy.website.self_link
}