FROM openfoam/openfoam2312-default:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
	python3 \
	python3-pip \
	curl \
	jq \
	&& rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK
RUN curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/opt
ENV PATH="/opt/google-cloud-sdk/bin:${PATH}"

# Copy entrypoint script
COPY entrypoint.sh /opt/cfd/entrypoint.sh
RUN chmod +x /opt/cfd/entrypoint.sh

# Set working directory
WORKDIR /opt/cfd

ENTRYPOINT ["/opt/cfd/entrypoint.sh"]
