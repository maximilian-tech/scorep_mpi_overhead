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
    """
    Line‐plot <metric> vs Size (log-x, log-y) and, on a secondary y-axis,
    the %-overhead of  ON  relative to  OFF  for every toolchain/nodes/cores group.
    """
    # ------------------------------------------------------------------ figure
    fig, ax = plt.subplots(figsize=(10, 13))

    # ------------------------------------------------------------------ left-axis: absolute metric
    df["label"] = (
        df["benchmark"]
        + " | "
        + df["instrumentation"]
        + " | nodes="
        + df["nodes"].astype(str)
        + " | cores="
        + df["cores"].astype(str)
        + " | toolchain="
        + df["toolchain"]
    )

    for label, grp in df.groupby("label"):
        g = grp.sort_values("Size")
        ax.plot(
            g["Size"],
            g[metric],
            marker="o",
            label=label,
        )
        # Error bars only for the mean metric
        if metric == "grand_mean_avg":
            ax.errorbar(
                g["Size"],
                g[metric],
                yerr=g["se_avg"],
                fmt="none",
                capsize=3,
            )

    ax.set_xscale("log", base=2)
    ax.set_yscale("log", base=10)
    ax.set_xlabel("Message size (bytes)")
    ax.set_ylabel(ylab)
    ax.grid(True, which="both", ls="--", lw=0.4)
    ax.set_title("Evaluation of Score-P Overhead (Profile + Trace) on the OSU MPI Benchmarks")
    # ------------------------------------------------------------------ right-axis: %-overhead (ON vs OFF)
    ax2 = ax.twinx()
    ax2.set_ylabel("Overhead ON vs OFF  (%)")

    base_cols = ["toolchain", "nodes", "cores", "benchmark"]
    for key, grp in df.groupby(base_cols):
        # Split ON / OFF
        on  = grp[grp["instrumentation"] == "ON"]
        off = grp[grp["instrumentation"] == "OFF"]

        if on.empty or off.empty:
            continue  # cannot form an overhead curve for this group

        merged = pd.merge(
            on[["Size", metric]],
            off[["Size", metric]],
            on="Size",
            suffixes=("_on", "_off"),
        ).sort_values("Size")

        overhead = 100.0 * (merged[f"{metric}_on"] - merged[f"{metric}_off"]) / merged[f"{metric}_off"]

        label = (
            f"{key[3]} | nodes={key[1]} | cores={key[2]} "
            f"| toolchain={key[0]}  (overhead)"
        )
        ax2.plot(
            merged["Size"],
            overhead,
            ls="--",
            marker=None,
            label=label,
        )

    # ------------------------------------------------------------------ legends
    # Combine handles from both axes
    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    #ax2.legend(h1 + h2, l1 + l2, fontsize="small", loc="upper left")
    ax2.legend(
        h1 + h2,
        l1 + l2,
        loc="upper center",          # centered horizontally
        bbox_to_anchor=(0.5, -0.12), # (x-center, y)  y < 0 puts it outside
        ncol=1,                      # split into rows of 3 items – adapt to taste
        fontsize="small",
        frameon=True,
    )

    fig.tight_layout()
    fig.subplots_adjust(bottom=0.27)   # increase if legend still touches bottom edge
    fig.savefig(fname, dpi=200)
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

    #df = df[
         #(df["benchmark"] == "collective-osu_allreduce")
         #(df["benchmark"] == "collective-osu_allgatherv" )
      #&
      #(
            #(df["cores"] == 4)
            #|
            #(df["cores"] == 96)
         #)
      #&  (df["nodes"] == 1)
      #&  (df["toolchain"] == "gompi2024a")
      #&  (df["toolchain"] == "intel2024a")
    #]

    # ------------------------------------------------------------------ plots
    out_base = str(csv_path.with_suffix(""))
    for benchmark in df["benchmark"].unique():
      df_tmp = df[
                  df["benchmark"] == benchmark
                ]
      plot_metric(df_tmp, "grand_mean_avg", "Mean latency (µs)", out_base + "_" + benchmark + "_mean.png")
      #plot_metric(df_tmp, "mean_p90", "Mean P90 latency (µs)", out_base + "_" + benchmark +"_p90.png")
      #plot_metric(df_tmp, "worst_p99", "Worst P99 latency (µs)", out_base + "_" + benchmark +"_p99.png")

    print(f"[done] PNGs written next to {csv_path}")


if __name__ == "__main__":
    main()