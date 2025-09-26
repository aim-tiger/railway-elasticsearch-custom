FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4
RUN bin/elasticsearch-plugin install analysis-kuromoji
