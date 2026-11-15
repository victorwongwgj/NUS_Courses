#!/usr/bin/env python3
"""Convert a single-cell .h5ad file (e.g. Tabula Sapiens, HLCA) into the binary files used here.

    python3 implementation/scripts/h5ad_to_bin.py tabula_sapiens.h5ad data/ts --pcs 50 [--label-key cell_ontology_class]
        [--subsample 10000 --seed 1]

Writes data/ts.feat.bin (float32 N x D PCA features), data/ts.labels.bin (int32 label codes) and
data/ts.label_names.txt. Then build the kNN graph with
    implementation/scripts/prepare.sh real-knn            (exact kNN, k = 90, on one GPU; see README.md)

Report data sets: the full Tabula Sapiens file gives `ts` (483k cells, 50 PCs, label key cell_type); the subsets ts10k / ts50k / ts200k
are random subsamples (--subsample 10000 / 50000 / 200000 --seed 1) of the same file.
Requires: numpy, anndata (pip install anndata) and scanpy only if the file has no X_pca.
"""
import argparse
import struct

import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("h5ad")
    ap.add_argument("out_prefix")
    ap.add_argument("--pcs", type=int, default=50)
    ap.add_argument("--label-key", default="cell_ontology_class")
    ap.add_argument("--subsample", type=int, default=0, help="keep only this many random cells (0 = all)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--inspect", action="store_true", help="only print shape, obsm keys and obs columns, then exit")
    a = ap.parse_args()

    import anndata

    # backed mode: the big expression matrix X stays on disk (a 19 GB file needs only obs/obsm in memory)
    ad = anndata.read_h5ad(a.h5ad, backed="r")
    if a.inspect:
        print("shape", ad.shape)
        print("obsm keys:", list(ad.obsm.keys()))
        print("obs columns:", list(ad.obs.columns))
        if a.label_key in ad.obs:
            print(a.label_key, "classes:", ad.obs[a.label_key].astype("category").cat.categories.size)
        return
    if "X_pca" in ad.obsm:
        x = np.asarray(ad.obsm["X_pca"])[:, : a.pcs]
    else:
        if ad.isbacked:
            raise SystemExit("no X_pca in obsm: the file must contain a PCA (run with --inspect to see obsm keys). "
                             "Computing PCA from raw counts needs the whole matrix in memory: use a job with enough memory and "
                             "edit the script to read without backed mode.")
        import scanpy as sc

        sc.pp.normalize_total(ad, target_sum=1e4)
        sc.pp.log1p(ad)
        sc.pp.highly_variable_genes(ad, n_top_genes=2000)
        sc.pp.pca(ad, n_comps=a.pcs)
        x = np.asarray(ad.obsm["X_pca"])
    n = x.shape[0]
    keep = np.arange(n)
    if a.subsample and a.subsample < n:
        rng = np.random.default_rng(a.seed)
        keep = np.sort(rng.choice(n, a.subsample, replace=False))
    x = np.ascontiguousarray(x[keep], dtype=np.float32)
    labels = -np.ones(len(keep), dtype=np.int32)
    names = []
    if a.label_key in ad.obs:
        cat = ad.obs[a.label_key].astype("category")
        labels = cat.cat.codes.to_numpy()[keep].astype(np.int32)
        names = list(cat.cat.categories)
    with open(a.out_prefix + ".feat.bin", "wb") as f:
        f.write(struct.pack("<qqq", 0x54534E4546454131, x.shape[0], x.shape[1]))
        x.tofile(f)
    with open(a.out_prefix + ".labels.bin", "wb") as f:
        f.write(struct.pack("<qq", 0x54534E454C424C31, len(labels)))
        labels.tofile(f)
    with open(a.out_prefix + ".label_names.txt", "w") as f:
        f.write("\n".join(names))
    print(f"wrote {x.shape[0]} cells x {x.shape[1]} PCs, {len(names)} label classes")


if __name__ == "__main__":
    main()
