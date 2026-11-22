resource "azurerm_monitor_action_group" "this" {
  name                = "ag-${var.name}"
  resource_group_name = var.resource_group_name
  short_name          = "aksgitops"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email == "" ? [] : [var.alert_email]

    content {
      name                    = "primary"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# Alert 1 of 2: node CPU. The second alert (deployment has no available
# replicas) is a PrometheusRule shipped with the Helm chart.
resource "azurerm_monitor_metric_alert" "node_cpu" {
  name                = "alert-${var.name}-node-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_id]
  description         = "Average node CPU above ${var.cpu_threshold_percent}% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.cpu_threshold_percent
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}
