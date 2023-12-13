##############
### Alerts ###
##############

# Policy
resource "newrelic_alert_policy" "policy" {
  name                = "Dashboard snapshot policy"
  incident_preference = "PER_CONDITION"
}

# Condition
resource "newrelic_nrql_alert_condition" "condition" {
  account_id = var.NEW_RELIC_ACCOUNT_ID
  policy_id  = newrelic_alert_policy.policy.id
  type       = "static"
  name       = "Dashboard snapshot condition"

  description = <<-EOT
  Incoming dashboard snapshot URL!
  EOT

  enabled                      = true
  violation_time_limit_seconds = 86400

  nrql {
    query = "FROM ${local.custom_event_name} SELECT count(*)"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_timer"
  aggregation_timer  = 5
}
