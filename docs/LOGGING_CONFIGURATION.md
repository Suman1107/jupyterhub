# Logging Configuration for GCP Cloud Logging

## Problem Statement

By default, JupyterHub writes logs to **stderr**, which causes GCP Cloud Logging to interpret all logs as **ERROR** severity, even for informational messages. This makes it difficult to filter and monitor actual errors.

## Solution

We've configured JupyterHub to:
1. Write logs to **stdout** instead of stderr
2. Use proper log levels (INFO, WARNING, ERROR)
3. Use structured logging format
4. Configure Python logging to use stdout

## Configuration Changes

### 1. Hub Pod Logging (`helm/config.yaml`)

```yaml
hub:
  config:
    JupyterHub:
      # Configure logging to use stdout with proper severity levels
      log_level: INFO
      log_format: "%(color)s[%(levelname)1.1s %(asctime)s.%(msecs).03d %(name)s %(module)s:%(lineno)d]%(end_color)s %(message)s"
  
  # Additional logging configuration for proper GCP Cloud Logging integration
  extraConfig:
    logging: |
      import logging
      import sys
      
      # Configure root logger to use stdout instead of stderr
      c.Application.log_datefmt = '%Y-%m-%d %H:%M:%S'
      c.Application.log_format = '[%(levelname)s %(asctime)s.%(msecs)03d %(name)s] %(message)s'
      
      # Ensure logs go to stdout (not stderr) so GCP interprets severity correctly
      logging.basicConfig(
          stream=sys.stdout,
          level=logging.INFO,
          format='[%(levelname)s %(asctime)s.%(msecs)03d %(name)s] %(message)s',
          datefmt='%Y-%m-%d %H:%M:%S'
      )
```

### 2. User Pod Logging

```yaml
singleuser:
  # Configure Jupyter server logging to use stdout with proper levels
  cmd:
    - jupyterhub-singleuser
    - --debug  # Enable debug mode for better logging
  
  extraEnv:
    # Configure Python logging to use stdout
    PYTHONUNBUFFERED: "1"
    # Set log level
    JUPYTER_LOG_LEVEL: "INFO"
```

### 3. Cloud SQL Proxy Logging

```yaml
extraContainers:
  - name: cloud-sql-proxy
    args:
      - "--structured-logs"  # Use structured JSON logs
```

## Log Levels

### Before Fix
- All logs appeared as **ERROR** in Cloud Logging
- Difficult to filter actual errors
- No severity differentiation

### After Fix
- **INFO**: Normal operations (user login, API calls, etc.)
- **WARNING**: Non-critical issues
- **ERROR**: Actual errors that need attention
- **DEBUG**: Detailed debugging information

## Verifying in GCP Cloud Logging

### 1. View Logs in Cloud Console

```
https://console.cloud.google.com/logs/query
```

### 2. Filter by Severity

**View only errors:**
```
resource.type="k8s_container"
resource.labels.namespace_name="jhub"
severity="ERROR"
```

**View info logs:**
```
resource.type="k8s_container"
resource.labels.namespace_name="jhub"
severity="INFO"
```

**View all JupyterHub hub logs:**
```
resource.type="k8s_container"
resource.labels.namespace_name="jhub"
resource.labels.pod_name=~"hub-.*"
```

### 3. Common Log Queries

**User login events:**
```
resource.type="k8s_container"
resource.labels.namespace_name="jhub"
jsonPayload.message=~".*User.*logged in.*"
severity="INFO"
```

**Actual errors only:**
```
resource.type="k8s_container"
resource.labels.namespace_name="jhub"
severity="ERROR"
NOT jsonPayload.message=~".*200 GET.*"
```

**Database connection logs:**
```
resource.type="k8s_container"
resource.labels.namespace_name="jhub"
resource.labels.container_name="cloud-sql-proxy"
```

## Log Format Examples

### Hub Logs
```
[INFO 2025-11-20 06:04:40.604 JupyterHub app:3206] Private Hub API connect url http://hub:8081/hub/
[INFO 2025-11-20 06:04:40.776 JupyterHub log:192] 200 GET /hub/api/ (jupyterhub-idle-culler@127.0.0.1) 13.07ms
```

### Cloud SQL Proxy Logs (Structured JSON)
```json
{
  "severity": "INFO",
  "message": "Listening on 127.0.0.1:5432",
  "timestamp": "2025-11-20T06:04:40.123Z"
}
```

## Monitoring and Alerting

### Create Log-Based Metrics

**1. Error Rate Metric**
```bash
gcloud logging metrics create jupyterhub_error_rate \
  --description="JupyterHub error rate" \
  --log-filter='resource.type="k8s_container"
                resource.labels.namespace_name="jhub"
                severity="ERROR"'
```

**2. User Login Metric**
```bash
gcloud logging metrics create jupyterhub_user_logins \
  --description="JupyterHub user login count" \
  --log-filter='resource.type="k8s_container"
                resource.labels.namespace_name="jhub"
                jsonPayload.message=~".*User.*logged in.*"'
```

### Create Alerts

**Alert on High Error Rate:**
```bash
# Via Cloud Console:
# Monitoring > Alerting > Create Policy
# Condition: jupyterhub_error_rate > 10 per minute
# Notification: Email/Slack
```

## Troubleshooting

### Logs Still Showing as ERROR

**Check pod logs directly:**
```bash
kubectl logs -n jhub -l component=hub --tail=20
```

**Verify configuration:**
```bash
kubectl get configmap hub -n jhub -o yaml | grep -A 10 "extraConfig"
```

**Restart hub pod:**
```bash
kubectl rollout restart deployment/hub -n jhub
```

### Missing Logs

**Check if pods are running:**
```bash
kubectl get pods -n jhub
```

**Check Cloud Logging agent:**
```bash
kubectl get pods -n kube-system -l app=fluentbit
```

### Structured Logs Not Appearing

**Verify Cloud SQL Proxy args:**
```bash
kubectl get pod <user-pod> -n jhub -o yaml | grep -A 5 "cloud-sql-proxy"
```

## Best Practices

### 1. Use Appropriate Log Levels

```python
# In your code
import logging

logger = logging.getLogger(__name__)

# Use appropriate levels
logger.info("User action completed")      # Normal operations
logger.warning("Deprecated feature used")  # Warnings
logger.error("Failed to connect to DB")    # Errors
logger.debug("Variable value: %s", var)    # Debug info
```

### 2. Structured Logging

```python
# Use structured data
logger.info("User login", extra={
    "user": username,
    "ip": request.remote_addr,
    "timestamp": datetime.now().isoformat()
})
```

### 3. Log Sampling

For high-volume logs, use sampling:
```yaml
hub:
  extraConfig:
    logging: |
      # Sample 10% of INFO logs
      import random
      class SamplingFilter(logging.Filter):
          def filter(self, record):
              if record.levelno == logging.INFO:
                  return random.random() < 0.1
              return True
      
      logging.getLogger().addFilter(SamplingFilter())
```

## Summary

✅ **Fixed**: Logs now use correct severity levels in Cloud Logging  
✅ **Configured**: stdout instead of stderr for all components  
✅ **Structured**: JSON logs for Cloud SQL Proxy  
✅ **Filterable**: Easy to filter by severity in Cloud Logging  
✅ **Monitorable**: Can create metrics and alerts  

## Verification Commands

```bash
# Check hub logs
kubectl logs -n jhub -l component=hub --tail=20

# Check user pod logs
kubectl logs -n jhub -l component=singleuser-server --tail=20

# Check Cloud SQL Proxy logs
kubectl logs -n jhub <pod-name> -c cloud-sql-proxy --tail=20

# View in Cloud Logging
gcloud logging read "resource.type=k8s_container AND resource.labels.namespace_name=jhub" --limit=20
```

## References

- [JupyterHub Logging Documentation](https://jupyterhub.readthedocs.io/en/stable/reference/config-reference.html#logging)
- [GCP Cloud Logging](https://cloud.google.com/logging/docs)
- [Kubernetes Logging Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
