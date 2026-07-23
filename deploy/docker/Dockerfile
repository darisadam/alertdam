# Stage 1: Build the Go binary
FROM golang:1.23-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Download dependencies (layer cache)
COPY backend/go.mod backend/go.sum ./
RUN go mod download

# Copy source and build
COPY backend/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)" \
    -o /pagerdam ./cmd/pagerdam/...

# Stage 2: Minimal runtime image
FROM scratch

# Import SSL certificates and timezone data from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the binary
COPY --from=builder /pagerdam /pagerdam

EXPOSE 8080

ENTRYPOINT ["/pagerdam"]
