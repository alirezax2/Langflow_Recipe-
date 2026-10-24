
# Official Langflow image; pin the version for reproducible deployments
FROM langflowai/langflow:1.13.0

# Langflow configuration
ENV LANGFLOW_HOST=0.0.0.0 \
    LANGFLOW_PORT=7860 \
    LANGFLOW_AUTO_LOGIN=false \
    LANGFLOW_CONFIG_DIR=/app/langflow \
    LANGFLOW_SAVE_DB_IN_CONFIG_DIR=true \
    LANGFLOW_CUSTOM_COMPONENT_ADMIN_ONLY=true \
    LANGFLOW_LOG_ENV=container

# Persistent application data directory
WORKDIR /app
RUN mkdir -p /app/langflow

# Langflow web UI and API
EXPOSE 7860

# Start Langflow
CMD ["langflow", "run", "--host", "0.0.0.0", "--port", "7860"]
