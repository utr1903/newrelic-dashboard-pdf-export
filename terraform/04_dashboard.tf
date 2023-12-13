##################
### Dashboards ###
##################

# Dashboard
resource "newrelic_one_dashboard" "dashboard" {
  name = "My Dashboard"

  page {
    name = "My Page"

    # Page Description
    widget_markdown {
      title  = "Page Description"
      row    = 1
      column = 1
      height = 2
      width  = 4

      text = "## Lorem Ipsum"
    }
  }
}
