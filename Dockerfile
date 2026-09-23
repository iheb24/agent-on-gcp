# Use the official Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install curl for HEALTHCHECK and uv for fast dependency resolution
# DL3008 is ignored because pinning curl version across debian updates is fragile
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv

# Copy the pyproject.toml
COPY pyproject.toml .

# Install dependencies using uv
RUN uv pip install --system .

# Copy the application code
COPY src/ src/

# Create a non-root user
RUN useradd -m appuser
USER appuser

# Expose port (Cloud Run defaults to 8080)
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1

# Command to run the application using ADK natively
CMD ["adk", "api_server", "src/agent/agent.py", "--host", "0.0.0.0", "--port", "8080"]
