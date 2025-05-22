# ───────── 1. CUDA & Ubuntu base (RunPod-compatible) ─────────
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# ───────── 2. System packages ─────────
RUN apt-get update && apt-get install -y \
    git build-essential cmake vim tmux \
    python3 python3-venv python3-dev python3-pip \
    libeigen3-dev libboost-all-dev \
    openbabel libopenbabel-dev \
    apbs pdb2pqr \
 && rm -rf /var/lib/apt/lists/*

# ───────── 3. Workspace layout ─────────
WORKDIR /workspace        # <- RunPod mounts your volume here
ENV PATH="/workspace/venv/bin:$PATH"

# ───────── 4. Python venv + core wheels ─────────


build-args: |
  GITHUB_USERNAME=${{ github.actor }}
  GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}


ARG GITHUB_USERNAME
ARG GITHUB_TOKEN

RUN python3 -m venv /workspace/venv && \
    /workspace/venv/bin/pip install --upgrade pip setuptools wheel && \
    /workspace/venv/bin/pip install \
      torch==2.2.2 torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu121 && \
    TORCH_VER=$(/workspace/venv/bin/python -c "import torch; print(torch.__version__)") && \
    /workspace/venv/bin/pip install \
      torch-scatter torch-sparse torch-cluster torch-spline-conv \
      -f https://data.pyg.org/whl/torch-${TORCH_VER}.html && \
    /workspace/venv/bin/pip install \
      numpy scipy pandas biopython prody spyrmsd rdkit-pypi \
      tokenizers transformers huggingface-hub wandb e3nn \
      scikit-learn accelerate prefetch_generator && \
    /workspace/venv/bin/pip install \
      git+https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/bioinfoUcsd/dimorphite_dl.git



# ───────── 5. Clone SurfDock and helpers ─────────
RUN git clone https://github.com/CAODH/SurfDock.git /workspace/SurfDock

# Facebook ESM (editable install)
RUN git clone --depth 1 https://github.com/facebookresearch/esm.git /workspace/SurfDock/esm \
 && pip install -e /workspace/SurfDock/esm

# Extract APBS / PDB2PQR bundle that SurfDock ships
RUN tar -xzf /workspace/SurfDock/comp_surface/tools/APBS_PDB2PQR.tar.gz -C /workspace/SurfDock/comp_surface/tools

# ───────── 6. Build & install MSMS (surface generator) ─────────
RUN git clone --depth 1 https://github.com/mgltools/msms.git /tmp/msms-src \
 && make -C /tmp/msms-src \
 && install /tmp/msms-src/msms.x86_64Linux* /usr/local/bin/msms \
 && rm -rf /tmp/msms-src

# ───────── 7. Patch hard-coded conda-activate line ─────────
RUN sed -i 's/^source .*activate.*//' /workspace/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh \
 && chmod +x /workspace/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh

# ───────── 8. Default to SurfDock directory & open shell ─────────
WORKDIR /workspace/SurfDock
ENTRYPOINT ["/bin/bash"]
