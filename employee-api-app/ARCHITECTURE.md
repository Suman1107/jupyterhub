# Employee API - Architecture Documentation

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet / Users                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX Ingress Controller                      │
│                    (LoadBalancer Service)                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Kubernetes Namespace: employee-api              │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              ClusterIP Service (Port 80)                │    │
│  └──────────────────────┬─────────────────────────────────┘    │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         Deployment: employee-api (2-10 replicas)        │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │   Pod 1      │  │   Pod 2      │  │   Pod N      │  │   │
│  │  │              │  │              │  │              │  │   │
│  │  │  FastAPI     │  │  FastAPI     │  │  FastAPI     │  │   │
│  │  │  Port: 8080  │  │  Port: 8080  │  │  Port: 8080  │  │   │
│  │  │              │  │              │  │              │  │   │
│  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │  │   │
│  │  │  │SQLite  │  │  │  │SQLite  │  │  │  │SQLite  │  │  │   │
│  │  │  │(shared)│  │  │  │(shared)│  │  │  │(shared)│  │  │   │
│  │  │  └────┬───┘  │  │  └────┬───┘  │  │  └────┬───┘  │  │   │
│  │  └───────┼──────┘  └───────┼──────┘  └───────┼──────┘  │   │
│  │          │                  │                  │          │   │
│  │          └──────────────────┼──────────────────┘          │   │
│  │                             │                              │   │
│  └─────────────────────────────┼──────────────────────────────┘   │
│                                │                                   │
│                                ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │     PersistentVolumeClaim: employee-api-data (1Gi)      │     │
│  │                 (GCE Persistent Disk)                    │     │
│  └─────────────────────────────────────────────────────────┘     │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │   HorizontalPodAutoscaler: employee-api-hpa             │     │
│  │   Min: 2, Max: 10, Target CPU: 70%                      │     │
│  └─────────────────────────────────────────────────────────┘     │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Google Cloud Platform                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         Artifact Registry: employee-api                 │    │
│  │         (Docker image repository)                       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         Cloud Build: CI/CD Pipeline                     │    │
│  │         - Build Docker image                            │    │
│  │         - Push to Artifact Registry                     │    │
│  │         - Deploy to GKE                                 │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Component Details

### Frontend Layer

**Technology**: HTML5 + Vanilla JavaScript  
**Features**:
- Modern, responsive UI with glassmorphism design
- Real-time updates every 30 seconds
- Form validation
- Smooth animations and transitions
- Mobile-friendly

**Files**:
- `static/index.html` - Main UI
- `static/js/app.js` - Frontend logic

### Backend Layer

**Technology**: Python FastAPI  
**Features**:
- RESTful API endpoints
- Async/await for high performance
- Pydantic models for validation
- Structured logging
- Health check endpoints
- CORS enabled

**Files**:
- `app/main.py` - FastAPI application
- `app/database.py` - Database layer
- `app/models.py` - Pydantic models
- `app/requirements.txt` - Dependencies

**API Endpoints**:
```
GET    /health              - Health check
GET    /api/employees       - List all employees
POST   /api/employees       - Add/update employee
DELETE /api/employees/:email - Delete employee
GET    /                    - Serve frontend
```

### Data Layer

**Technology**: SQLite with SQLAlchemy ORM  
**Storage**: GCE Persistent Disk via PVC  
**Features**:
- Async database operations
- Automatic schema creation
- Data persistence across pod restarts
- Shared volume for all replicas

**Schema**:
```sql
CREATE TABLE employees (
    email TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL
);
```

### Container Layer

**Base Image**: python:3.11-slim  
**Build**: Multi-stage for optimization  
**Security**:
- Non-root user (UID 1000)
- Minimal attack surface
- Health checks included

**Image Size**: ~150MB (optimized)

### Kubernetes Layer

**Namespace**: employee-api  
**Resources**:

1. **Deployment**
   - Replicas: 2 (min) - 10 (max)
   - Strategy: RollingUpdate
   - Resources: 100m-500m CPU, 128Mi-512Mi memory
   - Probes: Liveness + Readiness

2. **Service**
   - Type: ClusterIP
   - Port: 80 → 8080
   - Selector: app=employee-api

3. **Ingress**
   - Class: nginx
   - Path: / (all traffic)
   - Backend: employee-api:80

4. **PersistentVolumeClaim**
   - Size: 1Gi
   - Access: ReadWriteOnce
   - Storage Class: standard-rwo

5. **HorizontalPodAutoscaler**
   - Min: 2, Max: 10
   - CPU Target: 70%
   - Memory Target: 80%
   - Scale-up: Fast (100% or 2 pods per 30s)
   - Scale-down: Gradual (50% per 60s, 5min stabilization)

### Infrastructure Layer

**Managed by**: Terraform  
**Resources**:

1. **Artifact Registry**
   - Repository: employee-api
   - Format: Docker
   - Location: us-central1

2. **Cloud Build**
   - Trigger: Manual or GitHub
   - Steps: Build → Push → Deploy
   - Machine: N1_HIGHCPU_8

3. **IAM Permissions**
   - Cloud Build → Artifact Registry Writer
   - Cloud Build → GKE Developer
   - GKE → Artifact Registry Reader

### CI/CD Pipeline

**Tool**: Google Cloud Build  
**Trigger**: Manual or Git push  
**Steps**:

1. Build Docker image
2. Push to Artifact Registry (with tags: latest + version)
3. Get GKE credentials
4. Deploy namespace
5. Deploy PVC
6. Deploy application
7. Deploy service
8. Deploy ingress
9. Deploy HPA
10. Restart deployment
11. Wait for rollout
12. Verify deployment

**Duration**: ~5-10 minutes

## Data Flow

### Add Employee Flow

```
User Browser
    │
    ▼
POST /api/employees
    │
    ▼
NGINX Ingress
    │
    ▼
ClusterIP Service
    │
    ▼
Pod (FastAPI)
    │
    ├─► Validate with Pydantic
    │
    ├─► Check if exists (SQLAlchemy)
    │
    ├─► Insert/Update in SQLite
    │
    └─► Return response
        │
        ▼
    User Browser (success notification)
```

### Get Employees Flow

```
User Browser
    │
    ▼
GET /api/employees
    │
    ▼
NGINX Ingress
    │
    ▼
ClusterIP Service
    │
    ▼
Pod (FastAPI)
    │
    ├─► Query SQLite (ORDER BY created_at DESC)
    │
    ├─► Serialize with Pydantic
    │
    └─► Return JSON
        │
        ▼
    User Browser (render list)
```

## Scaling Behavior

### Horizontal Scaling (HPA)

**Scale Up Triggers**:
- CPU usage > 70%
- Memory usage > 80%

**Scale Up Behavior**:
- Add 100% of current pods OR 2 pods (whichever is larger)
- Every 30 seconds
- No stabilization window (immediate)

**Scale Down Triggers**:
- CPU usage < 70%
- Memory usage < 80%

**Scale Down Behavior**:
- Remove 50% of current pods
- Every 60 seconds
- 5-minute stabilization window

**Example Scaling**:
```
2 pods → High load → 4 pods (30s) → 8 pods (30s) → 10 pods (max)
10 pods → Low load → Wait 5min → 5 pods (60s) → Wait 5min → 2 pods (min)
```

### Vertical Scaling

**Resource Requests** (guaranteed):
- CPU: 100m (0.1 core)
- Memory: 128Mi

**Resource Limits** (maximum):
- CPU: 500m (0.5 core)
- Memory: 512Mi

## High Availability

### Redundancy
- Minimum 2 replicas at all times
- Pods distributed across nodes (if multi-node cluster)
- Rolling updates with zero downtime

### Health Checks

**Liveness Probe**:
- Endpoint: GET /health
- Initial delay: 10s
- Period: 30s
- Timeout: 5s
- Failure threshold: 3

**Readiness Probe**:
- Endpoint: GET /health
- Initial delay: 5s
- Period: 10s
- Timeout: 3s
- Failure threshold: 3

### Data Persistence
- SQLite database on persistent volume
- Survives pod restarts
- Backed by GCE Persistent Disk

## Security

### Container Security
- Non-root user (UID 1000)
- Dropped all capabilities
- No privilege escalation
- Read-only root filesystem (where possible)

### Network Security
- ClusterIP service (internal only)
- Ingress as single entry point
- CORS configured (can be restricted)

### Access Control
- Kubernetes RBAC (namespace isolation)
- IAM for GCP resources
- Service accounts for Cloud Build

## Monitoring & Observability

### Logs
- Structured JSON logging
- Sent to Cloud Logging
- Filterable by namespace, pod, container

### Metrics
- CPU and memory usage (via HPA)
- Request count and latency (via Ingress)
- Pod health status

### Alerts (Recommended)
- Pod crash loop
- High error rate
- Resource exhaustion
- Ingress unavailable

## Cost Optimization

### Compute
- Right-sized resource requests/limits
- HPA scales down during low traffic
- Efficient multi-stage Docker build

### Storage
- Small PVC (1Gi) for SQLite
- Compressed Docker layers

### Network
- ClusterIP (no external IPs for pods)
- Single Ingress IP

**Estimated Monthly Cost** (us-central1):
- GKE nodes: Shared with existing cluster
- PVC (1Gi): ~$0.17/month
- Artifact Registry: ~$0.10/month
- Cloud Build: ~$0.003/build-minute
- **Total**: < $5/month (excluding cluster costs)

## Disaster Recovery

### Backup Strategy
1. **Database**: Export SQLite file periodically
2. **Configuration**: All in Git (IaC)
3. **Images**: Versioned in Artifact Registry

### Recovery Steps
1. Restore Terraform state
2. Apply Terraform configuration
3. Deploy specific image version
4. Restore database from backup

**RTO** (Recovery Time Objective): < 15 minutes  
**RPO** (Recovery Point Objective): Depends on backup frequency

## Performance

### Expected Throughput
- **Per pod**: ~1000 req/s (simple CRUD)
- **With 2 pods**: ~2000 req/s
- **With 10 pods**: ~10,000 req/s

### Latency
- **Health check**: < 10ms
- **GET employees**: < 50ms (100 records)
- **POST employee**: < 100ms
- **DELETE employee**: < 50ms

### Database
- **SQLite**: Suitable for < 100,000 records
- **Concurrent writes**: Limited (SQLite limitation)
- **For production scale**: Consider Cloud SQL

## Future Enhancements

### Short Term
1. Add authentication (OAuth 2.0)
2. Enable HTTPS with SSL certificates
3. Set up custom domain
4. Add input sanitization
5. Implement rate limiting

### Medium Term
1. Migrate to Cloud SQL (PostgreSQL)
2. Add caching layer (Redis)
3. Implement audit logging
4. Add API versioning
5. Set up automated backups

### Long Term
1. Multi-region deployment
2. GraphQL API
3. WebSocket support for real-time updates
4. Advanced analytics
5. Integration with Google Workspace

## Integration Points

### Cloud Function Integration

```python
# In your Cloud Function
import requests

# Internal (if in same cluster)
API_URL = "http://employee-api.employee-api.svc.cluster.local/api/employees"

# External (via Ingress)
# API_URL = "http://<INGRESS_IP>/api/employees"

def sync_to_google_groups(request):
    # Fetch employees
    response = requests.get(API_URL)
    employees = response.json()["employees"]
    
    # Sync to Google Groups
    for emp in employees:
        add_to_group(emp["email"])
    
    return {"synced": len(employees)}
```

### Pub/Sub Integration (Future)

```python
# Publish event when employee added
from google.cloud import pubsub_v1

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, "employee-events")

# In create_employee endpoint
publisher.publish(
    topic_path,
    json.dumps({"action": "created", "email": email}).encode()
)
```

## Troubleshooting Guide

See [QUICKSTART.md](QUICKSTART.md) for detailed troubleshooting steps.

---

**Architecture Version**: 1.0  
**Last Updated**: 2025-11-21  
**Maintained By**: Infrastructure Team
