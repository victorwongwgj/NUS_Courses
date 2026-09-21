ARG MONGO_IMAGE=mongo:8.0
FROM ${MONGO_IMAGE}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends iptables iproute2 \
    && rm -rf /var/lib/apt/lists/*
