#!/bin/bash
KNOWN_BAD=fb149e4beb04d0e2661c84189635d103263a8fd4
KNOWN_GOOD=c0221e006d47ed24c4562f264411943596a6800e
cd /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/llvm-project
git bisect start $KNOWN_BAD $KNOWN_GOOD
git bisect run /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/auto_bisect_llvm_openmc/run.sh
git bisect reset
