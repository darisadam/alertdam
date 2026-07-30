# Deploy — AlertDam

Deployment manifests for various environments.

## Directory Structure

```
deploy/
├── docker/
│   └── Dockerfile       # Multi-stage Go build → minimal scratch image
└── k8s/
    └── README.md        # Kubernetes manifests (Phase 2+)
```

## Docker (Recommended for Self-Hosting)

The primary deployment method uses the root [`docker-compose.yml`](../docker-compose.yml).

```bash
# From the repository root
docker compose up -d
```

See the [deployment guide](../docs/deployment.md) for production configuration.

## Building the Docker Image

```bash
# From repository root
docker build -f deploy/docker/Dockerfile -t alertdam:latest .
docker build -f deploy/docker/Dockerfile -t alertdam:0.1.0 .
```

The image uses a **multi-stage build**:
1. Stage 1: `golang:1.23-alpine` — compiles the Go binary
2. Stage 2: `scratch` — copies only the binary (~10MB final image)

## Kubernetes (Phase 2+)

Kubernetes manifests will be added in Phase 2 (Hosted Beta). See [`k8s/README.md`](k8s/README.md).
