#!/usr/bin/env python3
from pathlib import Path
import sys

script_path = Path(__file__).resolve()

#ncores = [4,8,16,32,64,96]
#nnodes = [1,4]
ncores = [4,96]
nnodes = [1]

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

    #for scorep_enabled in ['scorepOFF', 'scorepON']:
    if True:
        # osu_dir: Path = tools_dir / f"osu_{toolchain_name}_{scorep_enabled}" / \
        #                             "libexec" / \
        #                             "osu-micro-benchmarks" / \
        #                             "mpi"

        for nodes in nnodes:
            for cores in ncores:
                #
                #scorep_experiment_dir = root_dir / "scorep_results" / f"{toolchain_name}_{scorep_enabled}_n{nodes:03d}_c{cores:05d}"

                common_part = f"{toolchain_name}_${{scorep_enabled}}_n{nodes:03d}_c{cores:05d}"
                name = common_part.replace(r"_${scorep_enabled}_","_")
                print(name)
                append = f"{root_dir}/results/{common_part}"
                rm_old_output_cmd = "\n".join(f"\trm -f {append}_{exe.replace('/','-')}" for exe in executables)

                append = f"{root_dir}/results/{common_part}"
                run_cmds = "\n".join(f'\t\tsrun ./{exe} -z >> "{append}_{exe.replace("/","-")}"' for exe in executables)

                osu_dir = f"{tools_dir}/osu_{toolchain_name}_${{scorep_enabled}}/libexec/osu-micro-benchmarks/mpi"

                sbatch_script = f"""
#!/bin/bash

#SBATCH -J {name}
#SBATCH -N {nodes}
#SBATCH -n {cores}
#SBATCH --switch=1
#SBATCH --time=00:15:00
#SBATCH --exclusive
#SBATCH --constraint=no_monitoring
#SBATCH --hint=nomultithread
#SBATCH --mem=0
#SBATCH --output="{root_dir}/jobs/{name}.out"
#SBATCH -x n1609,n1016

source {toolchain}
export PATH={scorep_bin_dir}:$PATH
export SCOREP_ENABLE_PROFILING=True
export SCOREP_ENABLE_TRACING=True

for scorep_enabled in scorepOFF scorepON ; do
{rm_old_output_cmd}
done

mkdir -p {root_dir}/scorep_results

for i in {{1..10}} ; do
  for scorep_enabled in scorepOFF scorepON ; do

    cd "{osu_dir}"
    export SCOREP_EXPERIMENT_DIRECTORY="{root_dir}/scorep_results/{common_part}"
 
{run_cmds}
    
  done
done
"""
                out = root_dir / "jobs" / f"{name}.sh"
                out.parent.mkdir(exist_ok=True, parents=True)
                out.write_text(sbatch_script.lstrip())
  
