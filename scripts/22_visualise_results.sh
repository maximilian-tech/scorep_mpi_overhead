#!/usr/bin/env python3
"""
Plot OSU-MPI latency summaries.
Works with either raw rows or pre-aggregated rows.
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


# -----------------------------------------------------------------------------#
#  Helpers                                                                     #
# -----------------------------------------------------------------------------#
RAW_COLUMNS = {
    "Size",
    "Avg Latency(us)",
    "P50 Tail Lat(us)",
    "P90 Tail Lat(us)",
    "P99 Tail Lat(us)",
    "toolchain",
    "instrumentation",
    "nodes",
    "cores",
    "benchmark",
}

AGG_COLUMNS = {
    "Size",
    "toolchain",
    "instrumentation",
    "nodes",
    "cores",
    "benchmark",
    "grand_mean_avg",
    "se_avg",
    "median_p50",
    "mean_p90",
    "worst_p90",
    "mean_p99",
    "worst_p99",
}


def aggregate_raw(df: pd.DataFrame) -> pd.DataFrame:
    """Turn the raw OSU lines into one row per (Size, toolchain, …)."""
    key = [
        "Size",
        "toolchain",
        "instrumentation",
        "nodes",
        "cores",
        "benchmark",
    ]

    out = (
        df.groupby(key, as_index=False)
        .agg(
            grand_mean_avg=("Avg Latency(us)", "mean"),
            se_avg=("Avg Latency(us)", lambda x: x.std(ddof=1) / np.sqrt(len(x))),
            median_p50=("P50 Tail Lat(us)", "median"),
            mean_p90=("P90 Tail Lat(us)", "mean"),
            worst_p90=("P90 Tail Lat(us)", "max"),
            mean_p99=("P99 Tail Lat(us)", "mean"),
            worst_p99=("P99 Tail Lat(us)", "max"),
        )
        .sort_values("Size")
    )
    return out


def plot_metric(df, metric, ylab, fname):
    """Generic line plot of <metric> vs Size, split by label."""
    fig, ax = plt.subplots(figsize=(8, 6))

    # Create a compact legend label
    df["label"] = (
        df["benchmark"]
        + " | "  # allgather / allreduce …
        + df["instrumentation"]
        + " | nodes="
        + df["nodes"].astype(str)
        + " | cores="
        + df["cores"].astype(str)
        + " | toolchain="
        + df["toolchain"].astype(str)
    )

    for label, grp in df.groupby("label"):
        grp_sorted = grp.sort_values("Size")
        ax.plot(
            grp_sorted["Size"],
            grp_sorted[metric],
            marker="o",
            label=label,
        )

        # Error bars for the mean plot
        if metric == "grand_mean_avg":
            ax.errorbar(
                grp_sorted["Size"],
                grp_sorted[metric],
                yerr=grp_sorted["se_avg"],
                fmt="none",
                capsize=3,
            )

    ax.set_xscale("log", base=2)
    ax.set_xlabel("Message size (bytes)")
    ax.set_yscale("log", base=10)
    ax.set_ylabel(ylab)
    ax.set_title(f"{ylab} vs message size")
    ax.legend(fontsize="small")
    ax.grid(True, which="both", ls="--", lw=0.4)
    fig.tight_layout()
    fig.savefig(fname, dpi=180)
    plt.close(fig)


# -----------------------------------------------------------------------------#
#  Main                                                                         #
# -----------------------------------------------------------------------------#
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", help="CSV file with OSU-MPI results (raw or aggregated)")
    args = ap.parse_args()

    csv_path = Path(args.csv)
    df = pd.read_csv(csv_path)

    # Decide whether the file is raw or already aggregated
    cols = set(df.columns)
    if RAW_COLUMNS.issubset(cols):
        print("[info] detected raw OSU-MPI rows – aggregating …")
        df = aggregate_raw(df)
    elif AGG_COLUMNS.issubset(cols):
        print("[info] detected pre-aggregated rows – plotting directly.")
    else:
        raise ValueError(
            "CSV does not match expected schema for raw or aggregated data."
        )

    # Make sure numeric cols really are numeric
    numeric = [
        "Size",
        "grand_mean_avg",
        "se_avg",
        "mean_p90",
        "worst_p99",
    ]
    df[numeric] = df[numeric].apply(pd.to_numeric, errors="coerce")
    # ------------------------------------------------------------------ filter

    df = df[
         (df["benchmark"] == "collective-osu_allreduce")
      &  (df["cores"] == 8)
      #&  (df["nodes"] == 1)
    ]

    # ------------------------------------------------------------------ plots
    out_base = str(csv_path.with_suffix(""))
    plot_metric(df, "grand_mean_avg", "Mean latency (µs)", out_base + "_mean.png")
    plot_metric(df, "mean_p90", "Mean P90 latency (µs)", out_base + "_p90.png")
    plot_metric(df, "worst_p99", "Worst P99 latency (µs)", out_base + "_p99.png")

    print(f"[done] PNGs written next to {csv_path}")


if __name__ == "__main__":
    main()