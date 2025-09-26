FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4
USER root

# 3. As root, install the plugin
RUN bin/elasticsearch-plugin install analysis-kuromoji

# 4. As root, fix the permissions for the data directory placeholder
RUN chown -R 1000:1000 /usr/share/elasticsearch/data