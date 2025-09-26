# Final Dockerfile - New Strategy

# 1. Start from the official image
FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4

# 2. Switch to ROOT to perform administrative tasks
USER root

# 3. Create a NEW directory for data and set its ownership to the elasticsearch user
# We are abandoning the problematic default directory.
RUN mkdir /data && chown elasticsearch:elasticsearch /data

# 4. Install the plugin
RUN bin/elasticsearch-plugin install analysis-kuromoji

# 5. Switch back to the non-privileged user for security.
# The main process will now run as 'elasticsearch'.
USER elasticsearch