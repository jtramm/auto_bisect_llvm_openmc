#!/bin/bash

START_DIR=$PWD

HISTORICAL_LOG=$START_DIR/historical_log.csv

# Navigate to LLVM outer directory
cd /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers

# Compile LLVM
./compile_llvm_ci.sh

# Load new LLVM environment
module use /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/Modules/modulefiles

module load spack
module load hdf5
module load cmake
module load llvm/ci
module load rocm/5.4.0

# Navigate to OpenMC
cd /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/openmc

# Compile OpenMC
rm -rf build
mkdir build
cd build

CLANG_VERSION=$(clang++ --version | grep version | cut -d ' ' -f 5 | cut -d ')' -f 1)
OPENMC_VERSION=$(git rev-parse HEAD)

cmake --preset=llvm_mi250 -Dcuda_thrust_sort=off -Dsycl_sort=off -Dhip_thrust_sort=on -Ddebug=off -Ddevice_printf=off -Doptimize=on -DCMAKE_INSTALL_PREFIX=./install ..
make install

module load openmc/ci

# Run OpenMC Test, storing results in a file
cd /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/openmc_offloading_benchmarks/progression_tests/XXL

TEST_LOG=test_results.txt

timeout 300 openmc --event &> $TEST_LOG

EXIT_CODE=$?

# Grep for correctness

# Result Validation
TEST_RESULT=$(cat ${TEST_LOG}      | grep "Absorption" | cut -d '=' -f 2 | xargs)
EXPECTED_RESULT=$(cat expected_results.txt | grep "Absorption" | cut -d '=' -f 2 | xargs)

PASS=1
if [ "$TEST_RESULT" == "$EXPECTED_RESULT" ]
then
  PASS=0
fi

# Compute FOM
FOM=$(cat ${TEST_LOG} | grep "(inactive" | cut -d '=' -f 2 | cut -d 'p' -f 1 | cut -d ' ' -f 2 | xargs)

# Output to historical log

printf "%s, %s, %d, %.5f, %d, %.2e\n" $CLANG_VERSION $OPENMC_VERSION $PASS $TEST_RESULT $EXIT_CODE $FOM  >> $HISTORICAL_LOG

# Return true/false code to caller based on correctness

cd $START_DIR

exit $PASS