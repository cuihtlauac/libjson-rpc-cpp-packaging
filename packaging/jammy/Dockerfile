FROM ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive

# Only install minimal tools needed to bootstrap the build process
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
