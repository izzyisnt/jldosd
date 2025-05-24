# syntax=docker/dockerfile:1.6
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

ARG PYTHON_VERSION=3.10
ARG SURFDOCK_REF=master
ARG MSMS_VER=2.6.1
ARG TORCH_VER=2.2.0          # ← pinned so PyG wheels exist
ENV DEBIAN_FRONTEND=noninteractive

# ── 0. entrypoint: copy early so cache is cheap ────────────────────────────────
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
 && /docker-entrypoint.sh echo "__entrypoint_ok__"

# ── 1. system packages ─────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget file build-essential cmake \
        python3.10 python3-venv python3-dev python3-pip \
        libboost-all-dev=1.74.0.3ubuntu7 \
        openbabel libopenbabel-dev \
        apbs pdb2pqr \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Python venv in /usr/local ───────────────────────────────────────────────
ENV VIRTUAL_ENV=/usr/local/venv
RUN python3 -m venv $VIRTUAL_ENV && \
    $VIRTUAL_ENV/bin/pip install --upgrade pip setuptools wheel
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# ── 3. heavy wheels (Torch + PyG CUDA ops) ─────────────────────────────────────
# torch / torchvision wheels
RUN pip install --no-cache-dir \
      https://download.pytorch.org/whl/cu121/torch-${TORCH_VER}%2Bcu121-cp310-cp310-linux_x86_64.whl \
      https://download.pytorch.org/whl/cu121/torchvision-0.17.0%2Bcu121-cp310-cp310-linux_x86_64.whl

# PyTorch-Geometric low-level CUDA wheels + wrapper
RUN pip install --no-cache-dir \
      -f https://data.pyg.org/whl/torch-${TORCH_VER}%2Bcu121.html \
      pyg_lib torch_scatter torch_sparse torch_cluster torch_spline_conv && \
    pip install --no-cache-dir torch_geometric

# ── 4. light Python deps ───────────────────────────────────────────────────────
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt
RUN pip install --no-cache-dir "MDAnalysis[analysis]" plyfile

# ── 5. SurfDock & ESM ──────────────────────────────────────────────────────────
RUN git clone --depth 1 --branch $SURFDOCK_REF https://github.com/CAODH/SurfDock.git /usr/local/SurfDock && \
    git clone --depth 1 https://github.com/facebookresearch/esm.git /usr/local/SurfDock/esm && \
    pip install --no-cache-dir -e /usr/local/SurfDock/esm && \
    tar -xzf /usr/local/SurfDock/comp_surface/tools/APBS_PDB2PQR.tar.gz \
        -C /usr/local/SurfDock/comp_surface/tools && \
    sed -i 's/^source .*activate.*//' \
        /usr/local/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh && \
    chmod +x /usr/local/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh

COPY utils/make_grids.py /opt/make_grids.py
RUN python /opt/make_grids.py /usr/local/SurfDock/precomputed_arrays

# ── 6. MSMS surface tools ─────────────────────────────────────────────────────
RUN curl -L -o /tmp/msms.tar.gz \
        https://ccsb.scripps.edu/msms/download/933/msms_i86_64Linux2_${MSMS_VER}.tar.gz && \
    mkdir -p /usr/local/msms && \
    tar -C /usr/local/msms -xzf /tmp/msms.tar.gz && \
    ln -s /usr/local/msms/msms.x86_64Linux2.${MSMS_VER} /usr/local/bin/msms && \
    ln -s /usr/local/msms/pdb_to_xyzr* /usr/local/bin/ && \
    sed -i 's@numfile = "./atmtypenumbers"@numfile = "/usr/local/msms/atmtypenumbers"@' \
        /usr/local/msms/pdb_to_xyzr /usr/local/msms/pdb_to_xyzrn && \
    rm /tmp/msms.tar.gz


# ── 8. runtime layout ──────────────────────────────────────────────────────────
WORKDIR /workspace           # RunPod mounts here

ENTRYPOINT ["/docker-entrypoint.sh"]
# keep-alive so Pod never exits; RunPod exec/web-shell attach fine
CMD ["tail","-f","/dev/null"]

# ── 8. Runtime layout ──────────────────────────────────────────────────────────
# RunPod mounts here
WORKDIR /workspace

# ── 9. Auto-venv activation + clean PS1 ────────────────────────────────────────
RUN echo 'source /usr/local/venv/bin/activate' >> /etc/bash.bashrc && \
    echo 'export PS1="% "' >> /etc/bash.bashrc && \
    echo 'alias surf="python /usr/local/SurfDock/inference_accelerate.py"' >> /etc/bash.bashrc && \
    echo 'alias gosurf="cd /usr/local/SurfDock"' >> /etc/bash.bashrc && \
    echo 'source /etc/bash.bashrc' >> /root/.bashrc

