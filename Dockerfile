# The Definitive Dockerfile - Manual gosu Installation

# 1. Start from the official image
FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4

# 2. Switch to ROOT to perform setup
USER root

# 3. (THE FIX) Manually download and install gosu.
# This bypasses the need for a specific package manager and will work on any Linux distribution.
RUN curl -sSL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu && \
    gosu --version

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