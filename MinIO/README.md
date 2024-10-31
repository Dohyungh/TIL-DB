SCV 프로젝트에서 학습된 모델을 임시 저장하는 용도로 MinIO를 사용한 기록입니다.

# MinIO

오브젝트 스토리지로, 객체를 오브젝트 형태로 저장하고, 메타데이터를 지정해 줄 수 있다.
Bucket 이라는 폴더 시스템을 사용한다.

> Kubeflow를 공부하다가 알게 된 오브젝트 스토리지이다. 모델 레지스트리, 모델 스토리지로 많이 사용하는 듯 하다.

- S3와 완벽하게 호환된다.
- Kubernetes를 짱짱하게 지원한다.

## docker-compose

```yml
version: "3.8"

services:
  minio:
    image: minio/minio
    container_name: scv-minio
    ports:
      - "9002:9002"
      - "9003:9003"
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
      - MINIO_VOLUMES=/data
    volumes:
      - ${VOLUME_PATH}:/data
      - ${CONFIG_DIR}:/etc
    command: server --address ":9002" --console-address ":9003"
```

Milvus와 마찬가지로 Docker-compose를 이용했다. 그러나, Kubernetes로 쓰기 좋다.

두 개의 포트를 사용하는데, 하나는 API 전용, 하나는 브라우저로 접속할 수 있는 컨트롤 대시보드이다. API 전용 포트로 브라우저 접속을 하면(http) 자동으로 대시보드 전용 포트로 리다이렉트 된다.

나는 9002번 포트에서 API를 지원하고, 9003번 포트에서 콘솔창(대시보드)를 지원하도록 설정했는데,
이는 Milvus에도 MinIO가 있어서 9000, 9001 번 포트를 이미 사용중이었기 때문이다. 외부 접속 포트와 내부 사용 포트를 동일하게 맞출 경우,
마지막 CMD 라인에서 `--address ":${PORT}"` 와 `--console-address ":${PORT}"` 을 설정해주어야 한다.

## Client

### MinIO Client (MC)

CLI 툴을 지원한다. Linux, MacOS, Windows 모두 사용 가능하다.

### Python SDK

```
pip install minio
```

## MinIO에 파일 업로드 하기

모델 학습 코드는 다른 팀원이 작성하기 때문에, 학습이 끝나면 MinIO에 모델을 저장할 수 있도록 파일을 만들어 주었다.

### save_model.py

```python
# prompt: Mnist 를 학습하는 분류 cnn 모델을 pytorch.sequantial 모듈을 이용해서 만들어줘. 학습과정과 추론까지 포함해서

import torch
import io

from minio import Minio
from dotenv import load_dotenv
import os

load_dotenv(verbose=True)
minio_user_name=os.getenv("MINIO_USER_NAME")
minio_user_password=os.getenv("MINIO_USER_PASSWORD")
minio_host_name=os.getenv("MINIO_HOST_NAME")
minio_model_bucket=os.getenv("MINIO_MODEL_BUCKET")

client = Minio("{}:9002".format(minio_host_name),
        access_key=minio_user_name,
        secret_key=minio_user_password,
        # SSL 설정 해제
        secure=False
    )

if not client.bucket_exists(minio_model_bucket):
        client.make_bucket(minio_model_bucket)

def save_model_to_minio(model, file_name: str):
    # 모델 저장
    buffer = io.BytesIO()
    torch.save(model, buffer)
    buffer.seek(0)
    client.put_object(minio_model_bucket, file_name, buffer, length=buffer.getbuffer().nbytes)
```

SSL 설정을 해야 할지 고민이 된다. 본 스토리지에 직접 접근이 불가능하고, Kubernetes로 조직된 컨테이너 네트워크 상에서 이미 앞단에서 거를 것이기 때문에 안해줘도 되는가? 이중 안전 장치를 걸어야 되는가?

일단 해제해놓고 테스트 했다.

---

모델을 저장할 때에는 모델을 일단 `torch.save` 로 파일로 저장한 이후에 파일을 MinIO에 업로드 하는 방법이 있고(`fput_object`) 바로 객체를 Stream 형식(`put_object`)으로 저장하는 방법이 있다.

모델 학습 컨테이너는 일회성으로 실행되는 것이 아니라 지속적으로 떠있을 것이기 때문에 임시 파일을 내부에서 만들고 업로드 할 경우 파일이 계속 쌓이고, 올리고 나서 지워줘야 하는 불편함이 있다.

따라서 io.BytesIO를 이용해 파일 생성 없이 업로드 하는 방법을 선택했다.

### app.py

```python
# 모델 학습 요청을 받을 FastAPI

# 모델 저장 함수 import
from save_model import save_model_to_minio

# 모델 학습을 완료하고 함수로 모델을 MinIO에 저장해 주세요.
# save_model_to_minio(model, "MODEL_VERSION_ID")
```
