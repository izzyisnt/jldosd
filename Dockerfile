# ───────── 0. GPU-enabled Micromamba base ─────────
FROM mambaorg/micromamba:jammy-cuda-12.1.0

ARG MAMBA_DOCKERFILE_ACTIVATE=1        # auto-activate env in each RUN

# ───────── 1. System libs the README calls for ─────────
# (the list below matches “Section 1 : Setup Environment” in the README)
USER root
RUN apt-get update && apt-get install -y \
      git build-essential cmake vim tmux \
      libeigen3-dev libboost-all-dev \
      openbabel libopenbabel-dev \
      apbs pdb2pqr && \
    rm -rf /var/lib/apt/lists/*

# ───────── 2. Clone code exactly as the README says ─────────
WORKDIR /workspace
RUN git clone --depth 1 \
        https://github.com/CAODH/SurfDock.git


# ───────── 3. Conda env (no more “-p” flag!) ─────────
COPY environment.yaml /workspace/SurfDock/environment.yaml
RUN micromamba create -n surfdock -f /workspace/SurfDock/environment.yaml \
 && micromamba install -y -n surfdock -f /workspace/SurfDock/environment.yaml \
 && micromamba clean --all --yes



# ───────── 4. Build the SurfDock C++/CUDA extensions (README §3) ─────────
WORKDIR /workspace/SurfDock
RUN /bin/bash -lc "python setup.py install"

# ───────── 5. Default entry ─────────
ENV PYTHONUNBUFFERED=1
CMD ["bash"]
