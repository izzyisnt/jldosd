FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
      git curl python3 python3-venv python3-pip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
RUN python3 -m venv /workspace/venv && \
  /workspace/venv/bin/pip install --upgrade pip && \
  /workspace/venv/bin/pip install torch==2.2.2 --index-url https://download.pytorch.org/whl/cu121

ENV PATH="/workspace/venv/bin:${PATH}"

# Keep the pod alive but lightweight
ENTRYPOINT ["tail","-f","/dev/null"]
