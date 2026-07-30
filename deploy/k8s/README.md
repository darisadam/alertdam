# Kubernetes Deployment (Phase 2+)

Kubernetes manifests for PagerDam will be added in **Phase 2 (Hosted Beta)**.

For now, please use the Docker Compose deployment:
```bash
docker compose up -d
```

See the [deployment guide](../../docs/deployment.md) for more details.

---

When Phase 2 begins, this directory will contain:
- `namespace.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `configmap.yaml`
- `secret.yaml` (template)
- `postgres-statefulset.yaml`
