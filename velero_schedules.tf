# Daily Automated Backup Schedule
resource "kubernetes_manifest" "velero_daily_schedule" {
  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"

    metadata = {
      name      = "daily-cluster-backup"
      namespace = "velero"
      labels = {
        "component" = "velero-schedule"
        "managed-by" = "terraform"
      }
    }

    spec = {
      # Standard Cron expression (e.g., Every day at 2:00 AM UTC)
      schedule = "0 2 * * *"

      template = {
        # Retention period for backups created by this schedule
        ttl = "720h0m0s" # 30 days

        # Namespaces to include in the backup
        includedNamespaces = [
          "default",
          "production"
        ]

        # Exclude system namespaces if desired
        excludedNamespaces = [
          "kube-system",
          "velero"
        ]

        # Include cluster-scoped resources (e.g., PVs, CRDs, ClusterRoles)
        includeClusterResources = true

        # Enable/disable volume snapshots (EBS, EFS, etc.)
        snapshotVolumes = true

        # Default Storage Location configured in Helm deployment
        storageLocation = "default"

        # Hooks to run scripts inside pods before/after snapshot (optional)
        hooks = {}
      }
    }
  }

  # Ensure the Velero Helm release is fully deployed before applying the Schedule CRD
  depends_on = [
    helm_release.velero
  ]
}