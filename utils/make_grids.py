#!/usr/bin/env python
import numpy as np, os, itertools, math, pathlib, sys

out = pathlib.Path(sys.argv[1]).expanduser()
out.mkdir(parents=True, exist_ok=True)

angles = np.linspace(0, 2*math.pi, 5, endpoint=False)
so3 = []
for a, b, g in itertools.product(angles, angles, [0]):
    ca, sa = math.cos(a), math.sin(a)
    cb, sb = math.cos(b), math.sin(b)
    cg, sg = math.cos(g), math.sin(g)
    so3.append([[ca*cb*cg - sa*sg, -ca*cb*sg - sa*cg, ca*sb],
                [sa*cb*cg + ca*sg, -sa*cb*sg + ca*cg, sa*sb],
                [-sb*cg, sb*sg, cb]])
np.save(out / "so3_grid_25.npy", np.array(so3, dtype=np.float32))
torus = np.stack(np.meshgrid(angles, angles, indexing="ij"), -1).reshape(-1, 2).astype(np.float32)
np.save(out / "torus_grid_25.npy", torus)
np.save(out / "index_map_25.npy", np.arange(25, dtype=np.int32))
