# Final Dockerfile v2 - Now with gosu installation

# 1. Start from the official image
FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4

# 2. Switch to ROOT to perform setup
USER root

# 3. (NEW STEP) Install gosu, a tool for switching users.
#    The base image is Debian/Ubuntu-based, so we use apt-get.
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# 4. Create the data directory mount point
RUN mkdir /data

# 5. Install the plugin
RUN bin/elasticsearch-plugin install analysis-kuromoji

# 6. Copy our custom startup script into the image
COPY entrypoint.sh /entrypoint.sh

# 7. Make our script executable
RUN chmod +x /entrypoint.sh

# 8. Set our custom script as the new entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# 9. Set the default command to be passed to our entrypoint script
CMD ["elasticsearch"]