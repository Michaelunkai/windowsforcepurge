# Use a base image
FROM alpine:latest

# Install rsync and bash
RUN apk --no-cache add rsync bash

# Set the working directory
WORKDIR /app

# Copy everything within the current path to /home/
COPY . /home/

# Default runtime options
CMD ["rsync", "-aP", "/home/", "/home/"]
