# Final Dockerfile with Custom Entrypoint

# 1. Start from the official image
FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4

# 2. Ensure we are root to perform setup
USER root

# 3. Create the data directory mount point
RUN mkdir /data

# 4. Install the plugin
RUN bin/elasticsearch-plugin install analysis-kuromoji

# 5. Copy our custom startup script into the image
COPY entrypoint.sh /entrypoint.sh

# 6. Make our script executable
RUN chmod +x /entrypoint.sh

# 7. Set our custom script as the new entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# 8. Set the default command to be passed to our entrypoint script
CMD ["elasticsearch"]