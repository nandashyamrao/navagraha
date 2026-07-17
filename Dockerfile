# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────────
# Build stage
# ──────────────────────────────────────────────────────────────────────────────
FROM golang:1.24-alpine AS builder

# Version of dtctl to build (override with --build-arg DTCTL_VERSION=v0.34.0)
ARG DTCTL_VERSION=v0.34.0

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /src

# Clone exactly the requested tag
RUN git clone --depth 1 --branch "${DTCTL_VERSION}" \
      https://github.com/dynatrace-oss/dtctl.git .

# Resolve the short commit hash and build date at image build time
RUN COMMIT=$(git rev-parse --short HEAD) \
 && DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
 && CGO_ENABLED=0 go build \
      -ldflags "-s -w \
        -X github.com/dynatrace-oss/dtctl/pkg/version.Version=${DTCTL_VERSION} \
        -X github.com/dynatrace-oss/dtctl/pkg/version.Commit=${COMMIT} \
        -X github.com/dynatrace-oss/dtctl/pkg/version.Date=${DATE}" \
      -o /out/dtctl \
      .

# ──────────────────────────────────────────────────────────────────────────────
# Final stage — scratch for minimal, distroless-style image
# ──────────────────────────────────────────────────────────────────────────────
FROM scratch

# CA certificates (needed for TLS calls to Dynatrace APIs)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Timezone data (optional, but useful for timestamp rendering)
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/dtctl /dtctl

ENTRYPOINT ["/dtctl"]
