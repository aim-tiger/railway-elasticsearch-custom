FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.4

# 2. 在构建镜像的过程中，运行插件安装命令
# 这会在最终的镜像中包含 Kuromoji 插件
RUN bin/elasticsearch-plugin install analysis-kuromoji

RUN chown -R 1000:1000 /usr/share/elasticsearch/data