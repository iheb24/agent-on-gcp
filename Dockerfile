# Use official slim Python runtime
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install curl for optional health probes and uv for fast package installation
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv

# Copy configuration and source files required for package installation
COPY pyproject.toml README.md ./
COPY src/ src/

# Install application dependencies directly into system environment
RUN uv pip install --system .

# Run as non-privileged numeric user for security compliance (hadolint DL3066)
RUN useradd -m -u 1000 appuser \
    && chown -R appuser:appuser /app
USER 1000:1000

# Cloud Run defaults to container port 8080
EXPOSE 8080

# Healthcheck probe for container monitoring in JSON exec notation (hadolint DL3025)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["curl", "-f", "http://localhost:8080/"]

# Serve the ADK Agent API server
CMD ["adk", "api_server", "src/agent/agent.py", "--host", "0.0.0.0", "--port", "8080"]
