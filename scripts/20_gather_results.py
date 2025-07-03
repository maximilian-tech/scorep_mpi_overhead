#!/usr/bin/env python3
import sys
import os
import re
import pandas as pd
import argparse

def load_table(path):
    # read all lines
    with open(path, 'r') as f:
        raw = [line.rstrip('\n') for line in f]

    # find last comment line for header
    header_idx = max(i for i, line in enumerate(raw) if line.lstrip().startswith('#'))
    header_line = raw[header_idx].lstrip('#').strip()
    cols = re.split(r'\s{2,}', header_line)

    # parse data after header
    data = []
    for line in raw:
        if not line.strip() or line.lstrip().startswith('#') or line.lstrip().startswith('rank') or line.lstrip().startswith('Dimension') or line.lstrip().startswith('Time'):
            continue
        data.append(re.split(r'\s{2,}', line.strip()))

    df = pd.DataFrame(data, columns=cols)
    # convert numeric columns
    for c in df.columns:
        df[c] = pd.to_numeric(df[c])

    # tag with source file
    filename: str = os.path.basename(path)

    filename_split = filename.split(r'_', 4)

    tc, instrumentation, nodes, cores, benchmark = filename_split 

    df['toolchain'] = tc
    df['instrumentation'] = instrumentation[len("scorep"):]
    df['nodes'] = pd.to_numeric(nodes[1:])
    df['cores'] = pd.to_numeric(cores[1:])
    df['benchmark'] = benchmark

    return df

def main():
    p = argparse.ArgumentParser(
        description="Parse one or more OSU Allreduce/Aggregate outputs into a single DataFrame"
    )
    p.add_argument('files', nargs='+', help='input text files')
    args = p.parse_args()

    dfs = [load_table(f) for f in args.files]
    result = pd.concat(dfs, ignore_index=True)
    print(result)

    result.to_csv("results.csv", index=False, sep=",")

if __name__ == '__main__':
    main()
