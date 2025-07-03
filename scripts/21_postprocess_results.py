#!/usr/bin/env python3

import pandas as pd
import numpy as np
import os

# 1. Read the raw CSV (⇧ copy-and-paste the block you posted into osu.csv)
df = pd.read_csv("results.csv")

# 2. Define which columns identify a “run configuration”
key_cols = ["Size", "toolchain", "instrumentation",
            "nodes", "cores", "benchmark"]

# 3. Aggregate
out = (df
       .groupby(key_cols, as_index=False)
       .agg(
           # --- Avg latency --------------------------------------------------
           grand_mean_avg = ("Avg Latency(us)", "mean"),
           se_avg         = ("Avg Latency(us)",
                              lambda x: x.std(ddof=1) / np.sqrt(len(x))),
           
           # --- P50 ----------------------------------------------------------
           median_p50     = ("P50 Tail Lat(us)", "median"),
           
           # --- P90 ----------------------------------------------------------
           mean_p90       = ("P90 Tail Lat(us)", "mean"),
           worst_p90      = ("P90 Tail Lat(us)", "max"),
           
           # --- P99 ----------------------------------------------------------
           mean_p99       = ("P99 Tail Lat(us)", "mean"),
           worst_p99      = ("P99 Tail Lat(us)", "max"),
       )
       .sort_values("Size")
)

# 4. Inspect
print(out.head())
out_dir = Path("../results_postprocessed")
out_dir.mkdir(exist_ok=True)
out.to_csv(f"{out_dir.name}/results_postprocess.csv", index=False, sep=",")
