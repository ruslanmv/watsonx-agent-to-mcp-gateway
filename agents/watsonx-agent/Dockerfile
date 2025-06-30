# Dockerfile
FROM python:3.11-slim

# Create a non-root user for better security
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /home/appuser/app

# Copy and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# Copy your agent code
COPY . .

# Fix permissions
RUN chown -R appuser:appuser /home/appuser/app
USER appuser

# Default to running your MCP server over stdio
ENTRYPOINT ["python", "server.py"]
