# Database-specific backup schedule with exec hooks
resource "kubernetes_manifest" "velero_db_schedule" {
  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = "db-consistent-backup"
      namespace = "velero"
    }
    spec = {
      schedule = "0 1 * * *" # 1 AM UTC
      template = {
        ttl                = "720h0m0s"
        includedNamespaces = ["database"]
        hooks = {
          resources = [
            {
              name               = "postgres-hook"
              includedNamespaces = ["database"]
              labelSelector = {
                matchLabels = { app = "postgresql" }
              }
              pre = [
                {
                  exec = {
                    container = "postgresql"
                    command   = ["psql", "-U", "postgres", "-c", "CHECKPOINT;"]
                    onError   = "Fail"
                    timeout   = "30s"
                  }
                }
              ]
            }
          ]
        }
      }
    }
  }

  depends_on = [helm_release.velero]
}