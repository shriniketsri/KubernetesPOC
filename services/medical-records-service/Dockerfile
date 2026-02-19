FROM golang:1.21-bullseye AS builder

# Install git and ca-certificates
RUN apt-get update && apt-get install -y git ca-certificates curl && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy go mod file
COPY go.mod ./

# Configure Go to completely bypass SSL verification for all problematic domains
ENV GOPROXY=direct
ENV GOSUMDB=off
ENV CGO_ENABLED=0
ENV GIT_SSL_NO_VERIFY=1
ENV GOPRIVATE=*
ENV GOINSECURE=*
ENV SSL_VERIFY=false

# Configure Git globally to skip SSL verification for all HTTPS
RUN git config --global http.sslverify false
RUN git config --global https.sslverify false
RUN git config --global http.postbuffer 1048576

# Copy all source files first (including go.mod)
COPY . .

# Try to build directly - Go will download dependencies during build
# This sometimes works when go mod download fails
RUN go build -mod=readonly -o main . || \
    (echo "Build failed, trying with mod=mod..." && go build -mod=mod -o main .)

# Final stage
FROM scratch

# Copy ca-certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary
COPY --from=builder /app/main /main

# Expose port
EXPOSE 3003

# Health check (note: scratch image doesn't have shell, so we use the binary)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/main", "health"] || exit 1

# Start the application
CMD ["/main"]