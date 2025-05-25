# syntax=docker/dockerfile:1.6
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
# system deps for APBS/PDB2PQR + build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget file build-essential cmake \
        apbs pdb2pqr \
        && rm -rf /var/lib/apt/lists/*

# ── micromamba (tiny conda) ────────────────────────────────────────
ENV MAMBA_ROOT_PREFIX=/opt/conda
RUN curl -L https://micromamba.snakepit.net/api/micromamba/linux-64/latest | \
    tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba && \
    micromamba shell init -s bash
ENV PATH=$MAMBA_ROOT_PREFIX/bin:$PATH

# copy env & create
COPY environment.yaml /tmp/environment.yaml
RUN micromamba install -y -n surfdock -f /tmp/environment.yaml && \
    micromamba clean -a -y

# activate conda env for every RUN after this line
SHELL ["micromamba", "run", "-n", "surfdock", "/bin/bash", "-c"]

# ── SurfDock + ESM ────────────────────────────────────────────────
RUN git clone --depth 1 https://github.com/CAODH/SurfDock.git /usr/local/SurfDock && \
    git clone --depth 1 https://github.com/facebookresearch/esm.git /usr/local/SurfDock/esm && \
    pip install -e /usr/local/SurfDock/esm

# unpack APBS/PDB2PQR bundle shipped with repo
RUN tar -xzf /usr/local/SurfDock/comp_surface/tools/APBS_PDB2PQR.tar.gz \
        -C /usr/local/SurfDock/comp_surface/tools

# ── deterministic grid generation ─────────────────────────────────
ENV precomputed_arrays=/usr/local/SurfDock/precomputed_arrays
RUN mkdir -p $precomputed_arrays && python - <<'PY'
import numpy as np, os, itertools, math
out = os.environ['precomputed_arrays']
angles = np.linspace(0, 2*math.pi, 5, endpoint=False)
so3 = []
for a, b in itertools.product(angles, angles):
    ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
    so3.append([[ca*cb, -ca*sb,  sa],
                [sa*cb, -sa*sb, -ca],
                [   sb,     cb,    0]])
np.save(f"{out}/so3_grid_25.npy", np.array(so3, dtype=np.float32))
np.save(f"{out}/torus_grid_25.npy", np.stack(np.meshgrid(angles, angles), -1)
                                     .reshape(-1,2).astype(np.float32))
np.save(f"{out}/index_map_25.npy", np.arange(25, dtype=np.int32))
PY

# ── prompt, env activation, alias ─────────────────────────────────
RUN echo 'source micromamba activate surfdock' >> /etc/bash.bashrc && \
    echo 'export precomputed_arrays=/usr/local/SurfDock/precomputed_arrays' >> /etc/bash.bashrc && \
    echo 'export PS1="surfdock@\\h:\\w\\$ "' >> /etc/bash.bashrc && \
    echo 'alias surf="python /usr/local/SurfDock/inference_accelerate.py"' >> /etc/bash.bashrc && \
    echo 'alias surf-eval="bash /usr/local/SurfDock/bash_scripts/test_scripts/eval_samples.sh"' >> /etc/bash.bashrc && \
    echo 'alias surf-screen="bash /usr/local/SurfDock/bash_scripts/test_scripts/screen_pipeline.sh"' >> /etc/bash.bashrc && \
    echo 'source /etc/bash.bashrc' >> /root/.bashrc

# ── runtime ──────────────────────────────────────────────────────
WORKDIR /workspace
ENTRYPOINT ["/bin/bash","-c"]
CMD ["tail","-f","/dev/null"]
