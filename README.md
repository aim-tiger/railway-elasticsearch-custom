好的，收到您的最终修订请求。将这些来自实践的宝贵经验更新到文档中，能让它变得更加完美和可靠。

这体现了技术文档的最佳实践：**持续迭代，反映现实**。

-----

## **Elasticsearch 搜索服务重构与部署手册 (最终修订版)**

**最后更新时间**: 2025年9月27日

### **引言：架构目标——两阶段查询 (Two-Phase Query)**

本手册旨在记录如何从零开始，为一个基于 Hasura 的系统搭建一个高性能、支持日语/英语专业搜索、数据持久化且能实时同步的 Elasticsearch 服务。

核心架构采用“两阶段查询”模式，以实现最佳的性能和数据一致性：

1.  **第一阶段 (识别)**: 客户端通过一个专用的 **Search Service** 调用 Elasticsearch，利用其强大的全文检索能力，快速获取匹配商品的 **ID 列表**。
2.  **第二阶段 (获取)**: 客户端使用这个 ID 列表，通过 **Hasura** 的 GraphQL API，从主数据库中高效地查询这些商品的完整、实时、带有关系的数据。

**架构图:**

```
+--------+   (1) Search         +---------------+   (2) Query ES      +-----------------+
| Client |  ---------------->  | Hasura Action |  -------------> |  Search Service |
+--------+                     +---------------+                  +-------+---------+
    ^                                                                     | (3) Return IDs
    | (5) Final Data                                                      v
    |                                                               +---------------+
    +-------------------------------------------------------------  | Elasticsearch |
      (4) Query Hasura with IDs                                     +---------------+
```

-----

### **目录**

1.  **[第一章：部署自定义 Elasticsearch 服务](https://www.google.com/search?q=%23chapter-1)**
2.  **[第二章：创建并配置 Elasticsearch 索引](https://www.google.com/search?q=%23chapter-2)**
3.  **[第三章：构建 Search Service 微服务](https://www.google.com/search?q=%23chapter-3)**
4.  **[第四章：实现数据同步](https://www.google.com/search?q=%23chapter-4)**
5.  **[第五章：最终验证流程](https://www.google.com/search?q=%23chapter-5)**

-----

\<a name="chapter-1"\>\</a\>

### **第一章：部署自定义 Elasticsearch 服务 (Railway)**

为了安装自定义插件并解决权限问题，我们必须从代码仓库部署一个基于自定义 `Dockerfile` 的服务。

#### **1.1 准备 GitHub 仓库**

在您的 GitHub 账户下创建一个新的代码仓库，其中包含以下核心文件：

**1. `Dockerfile` (核心构建文件)**

> **⚠️ 重要提示**: 文件名对大小写敏感！文件名必须是 `Dockerfile` (`D`大写, `f`小写)，而不是 `DockerFile` 或其他任何变体，否则 Railway 的自动检测会失败。

```dockerfile
# The Definitive Dockerfile - Manual gosu Installation

# 1. Start from the official image
FROM docker.elastic.co/elasticsearch/elasticsearch:8.11.3 # 您可以根据需要更新版本

# 2. Switch to ROOT to perform setup
USER root

# 3. Manually download and install gosu.
# This bypasses the need for a specific package manager like apt-get or yum.
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
```

**2. `entrypoint.sh` (运行时权限修复脚本)**

```sh
#!/bin/bash
set -e

# This script runs as ROOT when the container starts.

# 1. Fix the permissions of the /data directory.
#    This directory is the mount point for our persistent volume.
echo "Fixing permissions for /data..."
chown -R elasticsearch:elasticsearch /data

# 2. Hand over control to the original Elasticsearch entrypoint script,
#    but run it as the 'elasticsearch' user.
echo "Permissions fixed. Starting Elasticsearch as 'elasticsearch' user..."
exec gosu elasticsearch /usr/local/bin/docker-entrypoint.sh "$@"
```

**3. `railway.toml` (Railway 构建配置文件)**

> **注**: 这是 Railway 最新的标准配置文件名。如果自动检测 `Dockerfile` 失败，创建此文件可以明确地指导构建系统。

```toml
# railway.toml

# Explicitly tell the build system to use the Dockerfile.
[build]
builder = "docker"
```

#### **1.2 在 Railway 上部署**

1.  在 Railway 项目中，选择 **"New Service" -\> "Deploy from GitHub Repo"**，然后选择您刚刚创建的仓库。
2.  Railway 会自动检测到 `Dockerfile`（如果大小写正确）并开始构建。

#### **1.3 配置服务**

部署成功后，对该服务进行以下配置：

1.  **环境变量 (Variables)**:

      * `ELASTIC_PASSWORD`: 设置一个安全的密码。
      * `ES_JAVA_OPTS`: `-Xms512m -Xmx512m` (根据您的套餐内存调整，`512m` 是一个安全可靠的起点)。
      * `path.data`: `/data` (强制 ES 使用我们创建的新数据目录)。

2.  **存储卷 (Volumes)**:

      * 在项目主页，点击 **"+ New" -\> "Volume"** 来创建一个独立的存储卷。
      * 创建后，进入该 Volume 的设置，将其**附加 (Attach)** 到您的 Elasticsearch 服务上。
      * **Mount Path**: `/data`
      * **Size**: 根据您的数据量设置大小（例如 `20` GB）。

3.  **网络 (Networking)**:

      * 点击 **"Generate Domain"** 生成一个公开的访问 URL。

-----

\<a name="chapter-2"\>\</a\>

### **第二章：创建并配置 Elasticsearch 索引**

服务稳定运行后，通过 Kibana Dev Tools 创建索引。

1.  **访问 Kibana**: 在 Railway 上为您部署的 Kibana 服务中，配置好连接到新 ES 服务的环境变量。
2.  **创建索引**: 在 Kibana **Dev Tools** 中运行以下命令，创建一个名为 `products` 的索引，并配置好日语/英语分析器。

<!-- end list -->

```json
PUT /products
{
  "settings": {
    "analysis": {
      "analyzer": {
        "japanese_english_analyzer": {
          "type": "custom",
          "tokenizer": "kuromoji_tokenizer",
          "char_filter": [ "html_strip" ],
          "filter": [
            "kuromoji_baseform",
            "kuromoji_part_of_speech",
            "cjk_width",
            "lowercase"
          ]
        }
      }
    }
  },
  "mappings": {
    "dynamic": false,
    "properties": {
      "id": { "type": "keyword" },
      "name": {
        "type": "text",
        "analyzer": "japanese_english_analyzer",
        "fields": { "keyword": { "type": "keyword" } }
      },
      "description": {
        "type": "text",
        "analyzer": "japanese_english_analyzer"
      },
      // ... [其他字段，如 sku, price, status, visible, created_at 等]
    }
  }
}
```

-----

\<a name="chapter-3"\>\</a\>

### **第三章：构建 Search Service 微服务**

这是一个独立的、基于 Bun 和 ElysiaJS 的服务，负责处理搜索和实时同步。

#### **3.1 完整代码 (`search-service.ts`)**

请参考我们之前对话中生成的最终版 `search-service.ts` 代码。它应包含：

  * `/healthz` 健康检查端点。
  * `/search` 端点，实现 Two-Phase Query，仅返回 ID 列表。
  * `/sync` Webhook 端点，用于处理来自 Hasura 的实时事件。
  * 使用 `HttpConnection` 并禁用 TLS 验证的 Elasticsearch 客户端配置。

#### **3.2 依赖安装**

```bash
bun add elysia @elastic/elasticsearch @elastic/transport
```

#### **3.3 部署与配置 (Railway)**

1.  从包含此代码的 GitHub 仓库部署一个新服务。
2.  **Start Command**: `bun run src/es/app.ts` (根据您的文件路径调整)。
3.  **环境变量**:
      * `ES_HOST`: 指向第一章中创建的 ES 服务的公开 URL。
      * `ES_USERNAME`: `elastic`
      * `ES_PASSWORD`: ES 服务的密码。
      * `HASURA_EVENT_SECRET`: 创建一个安全的随机字符串作为 Webhook 密钥。

-----

\<a name="chapter-4"\>\</a\>

### **第四章：实现数据同步**

#### **4.1 首次批量导入**

使用一个一次性脚本将现有数据导入 ES。

1.  **安装依赖**: `bun add pg @types/pg`
2.  **创建脚本 (`bulk-import.ts`)**: 参考我们之前的对话，创建包含数据库连接、数据转换函数 (`transformProduct`) 和批量索引逻辑的脚本。确保 ES 客户端的初始化方式与 Search Service 中一致（使用 `HttpConnection`）。
3.  **配置 `.env` 文件**: 添加 `DATABASE_URL` 变量。
4.  **运行**: `bun run import:products`

#### **4.2 实时同步 (Hasura Event Trigger)**

1.  确保 `/sync` 端点已部署且 Search Service 正在运行。
2.  **在 Hasura Console 中**:
      * 导航到 `product` 表的 `Events` 标签页。
      * **Create Trigger**:
          * **Name**: `sync_product_to_es`
          * **Webhook URL**: 指向 Search Service 的 `/sync` 公开地址。
          * **Operations**: 勾选 `insert`, `update`, `delete`。
          * **Headers**: 添加一个名为 `x-webhook-secret` 的请求头，其值引用一个包含密钥的 Hasura 环境变量（该值必须与 Search Service 中的 `HASURA_EVENT_SECRET` 完全一致）。

-----

\<a name="chapter-5"\>\</a\>

### **第五章：最终验证流程**

1.  **验证持久化**:
      * 在 Kibana 中向一个测试索引（如 `test-persistence-index`）写入一条数据。
      * 读取该数据，确认存在。
      * 在 Railway 上**重新部署 (Redeploy)** Elasticsearch 服务。
      * 服务重启后，再次读取该数据，确认数据依然存在。这证明 Volume 配置正确。
2.  **验证实时同步**:
      * 在您的应用或 Hasura Console 中，**修改或删除**一条商品。
      * 立即去 Railway 查看 Search Service 的日志，确认收到了来自 Hasura 的 `🔄 收到 Hasura Event...` 日志。
3.  **验证端到端搜索**:
      * 在您的前端应用中执行一次搜索。
      * 确认能从 Hasura Action 收到商品 ID 列表。
      * 确认能用这些 ID 通过 Hasura GraphQL API 获取到完整的商品数据。

-----

至此，整个重构和部署流程全部完成。这份包含了您宝贵实践经验的文档，将成为未来工作的可靠指南。