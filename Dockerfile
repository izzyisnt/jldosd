# syntax=docker/dockerfile:1.6
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

ARG PYTHON_VERSION=3.10
ARG SURFDOCK_REF=main
ARG MSMS_VER=2.6.1
ENV DEBIAN_FRONTEND=noninteractive

# ───────── 1. System packages ─────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl build-essential cmake \
        python${PYTHON_VERSION} python3-venv python3-dev python3-pip \
        libeigen3-dev libboost-all-dev \
        openbabel libopenbabel-dev \
        apbs pdb2pqr \
    && rm -rf /var/lib/apt/lists/*

# ───────── 2. Python venv (in /usr/local) ─────────
ENV VIRTUAL_ENV=/usr/local/venv
RUN python3 -m venv $VIRTUAL_ENV && \
    $VIRTUAL_ENV/bin/pip install --upgrade pip setuptools wheel
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# ───────── 3. Core wheels ─────────
RUN pip install torch==2.2.2 torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu121

ENV TORCH_VER=2.2.2
RUN pip install torch==${TORCH_VER} torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# ───────── 4. Python deps ─────────
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt && rm /tmp/requirements.txt

# ───────── 5. SurfDock + ESM ─────────
RUN git clone --depth 1 --branch $SURFDOCK_REF https://github.com/CAODH/SurfDock.git /usr/local/SurfDock && \
    git clone --depth 1 https://github.com/facebookresearch/esm.git /usr/local/SurfDock/esm && \
    pip install -e /usr/local/SurfDock/esm && \
    tar -xzf /usr/local/SurfDock/comp_surface/tools/APBS_PDB2PQR.tar.gz \
        -C /usr/local/SurfDock/comp_surface/tools && \
    sed -i 's/^source .*activate.*//' /usr/local/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh && \
    chmod +x /usr/local/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh

# ───────── 6. MSMS ─────────
RUN curl -L -o /tmp/msms.tar.gz \
        https://ccsb.scripps.edu/msms/download/933/msms_i86_64Linux2_${MSMS_VER}.tar.gz && \
    mkdir -p /usr/local/msms && \
    tar -C /usr/local/msms -xzf /tmp/msms.tar.gz && \
    ln -s /usr/local/msms/msms.x86_64Linux2.${MSMS_VER} /usr/local/bin/msms && \
    ln -s /usr/local/msms/pdb_to_xyzr* /usr/local/bin/ && \
    sed -i 's@numfile = "./atmtypenumbers"@numfile = "/usr/local/msms/atmtypenumbers"@' \
        /usr/local/msms/pdb_to_xyzr /usr/local/msms/pdb_to_xyzrn && \
    rm /tmp/msms.tar.gz

# ───────── 7. Runtime layout ─────────
WORKDIR /workspace                          # RunPod mounts here
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bash"]
