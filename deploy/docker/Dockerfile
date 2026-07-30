# syntax=docker/dockerfile:1

# =============================================================================
# Stage 1: build the Go binary
#
# --platform=$BUILDPLATFORM pins the builder to the *native* architecture of the
# machine running the build, and the Go toolchain cross-compiles to $TARGETARCH.
# That makes `docker buildx build --platform linux/amd64,linux/arm64` fast
# without QEMU emulation, which would otherwise be 5-20x slower here.
# =============================================================================
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

# Provided automatically by buildx.
ARG TARGETOS
ARG TARGETARCH

# Version metadata. Passed in by CI (docker/metadata-action); `git describe`
# cannot be used inside this stage because the build context excludes .git.
ARG VERSION=dev
ARG REVISION=unknown
ARG BUILD_DATE=unknown

WORKDIR /build

RUN apk add --no-cache ca-certificates tzdata

# Dependency layer: cached until go.mod/go.sum change.
COPY backend/go.mod backend/go.sum ./
RUN go mod download

COPY backend/ ./

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -trimpath \
    -ldflags="-w -s \
      -X main.version=${VERSION} \
      -X main.commit=${REVISION} \
      -X main.date=${BUILD_DATE}" \
    -o /alertdam ./cmd/alertdam

# =============================================================================
# Stage 2: minimal runtime image
# =============================================================================
FROM scratch

ARG VERSION
ARG REVISION
ARG BUILD_DATE

LABEL org.opencontainers.image.title="AlertDam" \
      org.opencontainers.image.description="Self-hosted, ChatOps-first incident management and on-call alerting" \
      org.opencontainers.image.source="https://github.com/darisadam/alertdam" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /alertdam /alertdam

# Run unprivileged. `scratch` has no /etc/passwd, so this is a bare uid:gid.
USER 65532:65532

EXPOSE 8080

ENTRYPOINT ["/alertdam"]
