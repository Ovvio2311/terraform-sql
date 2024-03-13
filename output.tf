

output "client_token" {
  description = "The bearer token for auth"
  sensitive   = true
  value       = base64encode(data.google_client_config.default.access_token)
}

output "project" {
  value = data.google_client_config.default
  sensitive = true
}

