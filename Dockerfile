FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4
RUN bin/elasticsearch-plugin install analysis-kuromoji
RUN chown -R 1000:1000 /usr/share/elasticsearch/data