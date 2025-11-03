# The Definitive Dockerfile - Manual gosu Installation

# 1. Start from the official image
FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4

# 2. Switch to ROOT to perform setup
USER root

# 3. (THE FIX) Manually download and install gosu.
# This bypasses the need for a specific package manager and will work on any Linux distribution.
RUN set -eux; \
    # Ensure curl is available (try common package managers if needed)
    if ! command -v curl >/dev/null 2>&1; then \
        if [ -f /etc/alpine-release ]; then \
            apk add --no-cache curl; \
        elif command -v apt-get >/dev/null 2>&1; then \
            apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*; \
        elif command -v yum >/dev/null 2>&1; then \
            yum install -y curl; \
        else \
            echo "curl is required but no known package manager was found" >&2; \
            exit 1; \
        fi; \
    fi; \
    # Map kernel arch to gosu release arch
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) gosu_arch=amd64 ;; \
        aarch64|arm64) gosu_arch=arm64 ;; \
        *) gosu_arch="$arch" ;; \
    esac; \
    GOSU_VERSION=1.17; \
    url="https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${gosu_arch}"; \
    curl -fsSL -o /usr/local/bin/gosu "$url"; \
    chmod +x /usr/local/bin/gosu; \
    /usr/local/bin/gosu --version

# 4. Create the data directory mount point
RUN mkdir /data

# 5. Install the plugin
RUN bin/elasticsearch-plugin install analysis-kuromoji

# 6. Copy our custom startup script into the image
COPY entrypoint.sh /entrypoint.sh

# 7. Make our script executable
RUN chmod +x /entrypoint.sh

# 8. Set our custom script as the new entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# 9. Set the default command to be passed to our entrypoint script
CMD ["elasticsearch"]