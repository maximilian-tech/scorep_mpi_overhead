#!/usr/bin/env python3
from pathlib import Path
import sys

script_path = Path(__file__).resolve()

ncores = [4,8,16,32,64,96]
nnodes = [1,4]

root_dir: Path      = Path(script_path).parent.parent
tools_dir: Path     = root_dir / "tools"
toolchain_dir: Path = root_dir / "toolchains"

toolchains = list(toolchain_dir.iterdir())

executables = [
    "collective/osu_allgather",
    "collective/osu_allreduce",
]

for toolchain in toolchains:
    toolchain_name = Path(toolchain).name

    scorep_bin_dir: Path = tools_dir / ("scorep_" + toolchain_name ) / "bin"

    for scorep_enabled in ['scorepOFF', 'scorepON']:
        osu_dir: Path = tools_dir / f"osu_{toolchain_name}_{scorep_enabled}" / \
                                    "libexec" / \
                                    "osu-micro-benchmarks" / \
                                    "mpi"

        for nodes in nnodes:
            for cores in ncores:
                append = root_dir / "results" / f"{toolchain_name}_{scorep_enabled}_n{nodes:03d}_c{cores:05d}"
                scorep_experiment_dir = root_dir / "scorep_results" / f"{toolchain_name}_{scorep_enabled}_n{nodes:03d}_c{cores:05d}"

                rm_old_output_cmds = "\n".join(f"rm -f {append}_{exe.replace('/','-')}" for exe in executables)

                run_cmds = "\n".join(f"\tsrun ./{exe} -z >> {append}_{exe.replace('/','-')}" for exe in executables)

                sbatch_script = f"""
#!/bin/bash

#SBATCH -J {append.name}
#SBATCH -N {nodes}
#SBATCH -n {cores}
#SBATCH --switch=1
#SBATCH --time=00:15:00
#SBATCH --exclusive
#SBATCH --constraint=no_monitoring
#SBATCH --hint=nomultithread
#SBATCH --mem=0
#SBATCH -x n1609

source {toolchain}
export PATH={scorep_bin_dir}:$PATH
export SCOREP_EXPERIMENT_DIRECTORY={scorep_experiment_dir}
export SCOREP_ENABLE_PROFILING=True
export SCOREP_ENABLE_TRACING=True

mkdir -p "${{SCOREP_EXPERIMENT_DIRECTORY%/*}}"

cd {osu_dir}

{rm_old_output_cmds}

for i in {{1..10}} ; do
{run_cmds}
done
"""
                out = root_dir / "jobs" / f"{append.name}.sh"
                out.parent.mkdir(exist_ok=True, parents=True)
                out.write_text(sbatch_script.lstrip())
  
