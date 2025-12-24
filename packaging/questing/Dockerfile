FROM ubuntu:questing

ENV DEBIAN_FRONTEND=noninteractive

# Only install minimal tools needed to bootstrap the build process + enable universe
RUN apt-get update && apt-get install -y \
    software-properties-common \
    ca-certificates \
    && add-apt-repository universe \
    && rm -rf /var/lib/apt/lists/*
