SCV 프로젝트의 유사 레이어 검색 기능을 위해 Milvus를 사용한 기록입니다.

# Milvus

오픈 소스 Vector db이다. 컨테이너 이미지를 지원한다.  
성능 보다도 우선적으로 생각한 것이 위의 두가지 포인트였다.  
처음 써보는 만큼 러닝 커브를 최대한 줄이고 싶었다.

## Docker-Compose

프로젝트에서는 Infra 담당자가 Kubernetes를 사용하겠지만, 로컬환경에서 테스트 하기 위해서는 Docker-Compose 를 선택했다.

홈페이지에서는 Docker, Docker-compose 설치를 모두 안내하고 있는데, Docker 설치의 경우 minIO와 etcd가 한 컨테이너 내에서 작동하고, Docker-compose의 경우 각각 하나의 컨테이너로 동작한다. 에러 발생시 하나씩 관찰/조작 할 수 있는 점이 중요하기에 Docker-compose 방식을 선택했다.

```yml
version: "3.5"

services:
  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:v3.5.5
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/etcd:/etcd
    command: etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3

  minio:
    container_name: milvus-minio
    image: minio/minio:RELEASE.2023-03-20T20-16-18Z
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    ports:
      - "9001:9001"
      - "9000:9000"
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/minio:/minio_data
    command: minio server /minio_data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  standalone:
    container_name: milvus-standalone
    image: milvusdb/milvus:v2.4.13-hotfix
    command: ["milvus", "run", "standalone"]
    security_opt:
      - seccomp:unconfined
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/milvus:/var/lib/milvus
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 90s
      timeout: 20s
      retries: 3
    ports:
      - "19530:19530"
      - "9091:9091"
    depends_on:
      - "etcd"
      - "minio"

  # Attu 추가
  attu:
    image: zilliz/attu:latest
    container_name: milvus-attu
    ports:
      - "8000:3000" # Attu는 호스트의 포트 8000에서 접근 가능
    environment:
      MILVUS_URL: "standalone:19530" # Milvus standalone 컨테이너의 주소
    depends_on:
      - "standalone"

networks:
  default:
    name: milvus
```

원래 attu 는 공식문서에는 없는 컨테이너 인데, 이는 Milvus를 모니터링하기 위한 툴이다. 해당 툴에서 Collection을 생성하거나, 삭제하고 데이터를 직접 볼 수 도 있다. Collection을 load 하거나 unload하는 버튼도 지원한다.

## 초기화

항상 데이터베이스를 백엔드 쪽에서 올리고, 팀원들이 STS에서 gradle 진영으로 옮겨갔다 보니 어떻게 연결하는 지도 잘 몰랐다. 그래서 이번 기회에 백엔드 팀원들에게 물어보니 데이터베이스에 볼륨을 마운트해서 데이터는 하나의 볼륨에서 관리하고, 해당 볼륨을 바라보는 DB를 띄웠다 내렸다 한다는 것을 알았다.

Milvus 도 그런 방식으로 띄운다고 했을 때 이미 위에 있는 yml 파일에 보면

```yml
volumes:
  - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/milvus:/var/lib/milvus
```

부분에서 자동으로 생성된 volumes 폴더에서 마운트가 이루어지고 있다는 것을 알 수 있다.
정확히는 아직 모르겠지만, Database, schema, table 등의 모든 정보가 해당 폴더에 기록된단다.

그러면 이제 최초로 띄웠을 때 실행시킬 스크립트만 있으면 되겠다.

```python
from pymilvus import connections, db, FieldSchema, CollectionSchema, Collection, DataType, MilvusClient
from dotenv import load_dotenv
import os

conn = connections.connect(host=milvus_host_name, port=milvus_port)

load_dotenv(verbose=True)
db_name = os.getenv("DB_NAME")
collection_name = os.getenv("COLLECTION_NAME")
milvus_host_name = os.getenv("MILVUS_HOST_NAME")
milvus_port = os.getenv("MILVUS_PORT")

if not db_name in db.list_database():
    database = db.create_database(db_name)

client = MilvusClient(
    uri="http://{}:{}".format(milvus_host_name, milvus_port),
    db_name=db_name
)

db.using_database(db_name)

id_field = FieldSchema(
    name="model_version_layer_id",
    dtype=DataType.VARCHAR,
    max_length=30,
    is_primary=True,
    description="model, version, layer id 를 concat 해서 사용")

accuracy_field = FieldSchema(
    name="test_accuracy",
    dtype=DataType.FLOAT,
    description="test 정확도")

layer_field = FieldSchema(
    name="layers",
    dtype=DataType.VARCHAR,
    max_length=1024,
    description="모델의 레이어 정보를 담은 JSON 파일"
)

vector_field = FieldSchema(
    name="cka_vec",
    dtype=DataType.FLOAT_VECTOR,
    dim=3,
    description="cka 행렬 X 의 XX^T 를 취한 후에 Frobenius Norm으로 나눈 값")


schema = CollectionSchema(fields=[id_field, accuracy_field, layer_field, vector_field], description="collection with cka. pk is model_version_layer_id")

index_params = client.prepare_index_params()

index_params.add_index(
    field_name="model_version_layer_id",
    index_type="INVERTED"
)

index_params.add_index(
    field_name="cka_vec",
    index_type="FLAT",
    metric_type="IP",
)

client.create_collection(
    collection_name="cka_collection",
    schema=schema,
    index_params=index_params
)

client.release_collection(
    collection_name="cka_collection"
)
```

- client 를 통해 통신하는 방법이 있고, 직접 db, collection 모듈을 import해서 사용하는 방법이 있다. `get started`를 보면 두 방법이 좀 혼재되어 있다.
- client 방법이 전반적으로 편리한 것 같다.
- database를 생성하고, use 하고, Collection으로 관리한다.
- index를 생성해주어야(특히 Vector 컬럼) Collection을 메모리에 load해서 Collection을 조회할 수 있다. attu에서도 load를 해야 데이터가 보인다.
