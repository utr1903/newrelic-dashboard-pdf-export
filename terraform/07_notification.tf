####################
### Notification ###
####################

# Destination
resource "newrelic_notification_destination" "email" {
  account_id = var.NEW_RELIC_ACCOUNT_ID
  name       = "dashboard-snapshot-receiver-emails"
  type       = "EMAIL"

  property {
    key   = "email"
    value = "email@email.com,email2@email.com"
  }
}

# Channel
resource "newrelic_notification_channel" "email" {
  account_id     = var.NEW_RELIC_ACCOUNT_ID
  name           = "dashboard-snapshot"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "Dashboard Snapshot URL"
  }
}

# Workflow
resource "newrelic_workflow" "email" {
  name                  = "dashboard-snapshot"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "dashboard-snapshot-alert"
    type = "FILTER"

    predicate {
      attribute = "accumulations.policyName"
      operator  = "CONTAINS"
      values    = [newrelic_alert_policy.policy.name]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email.id
  }

  enrichments {
    nrql {
      name = "Dashboard snapshot URL"
      configuration {
        query = "FROM ${local.custom_event_name} SELECT uniques(snapshotURL)"
      }
    }
  }
}
