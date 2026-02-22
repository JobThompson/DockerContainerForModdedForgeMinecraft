# Use Eclipse Temurin JDK 17 as the base image (supports amd64 and arm64)
FROM eclipse-temurin:17-jdk

# Install required system packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        curl \
        jq \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /data /servers/modpack/mods /servers/modpack/config /backups /scripts

# Set working directory to server root
WORKDIR /data

# Copy scripts into the image
COPY scripts/ /scripts/
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /scripts/*.sh

# Expose the default Minecraft port
EXPOSE 25565

# Declare volumes for persistent data
VOLUME ["/data", "/servers", "/backups"]

# Healthcheck: verify the server process is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD pgrep -f "java.*server" > /dev/null || exit 1

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
