#!/bin/bash

TEST_START=$SECONDS

START_DIR=$PWD

TEST_DIR=/gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/auto_bisect_llvm_openmc

HISTORICAL_LOG=$TEST_DIR/historical_log.csv
TEST_LOG=$TEST_DIR/test_results.txt

# Navigate to LLVM outer directory
cd /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers

# Compile LLVM
./compile_llvm_ci.sh

LLVM_COMPILE_FAIL=1
CLANG_EXE=/gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/llvm-install-ci/bin/clang
if [ -f "$CLANG_EXE" ]; then
  LLVM_COMPILE_FAIL=0
fi

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

COMPILE_START=$SECONDS

cmake --preset=llvm_mi250 -Dcuda_thrust_sort=off -Dsycl_sort=off -Dhip_thrust_sort=on -Ddebug=off -Ddevice_printf=off -Doptimize=on -DCMAKE_INSTALL_PREFIX=./install .. &> $TEST_LOG
make install &>> $TEST_LOG

COMPILE_TIME=$(( SECONDS - COMPILE_START ))

module load openmc/ci

# Run OpenMC Test, storing results in a file
cd /gpfs/jlse-fs0/projects/intel_anl_shared/openmc_data/compilers/openmc_offloading_benchmarks/progression_tests/XXL

timeout 180 openmc --event &>> $TEST_LOG

EXIT_CODE=$?

# Grep for correctness

# Result Validation
TEST_RESULT=$(cat ${TEST_LOG}      | grep "Absorption" | cut -d '=' -f 2 | xargs)
EXPECTED_RESULT=$(cat expected_results.txt | grep "Absorption" | cut -d '=' -f 2 | xargs)

FAIL=1
if [ "$TEST_RESULT" == "$EXPECTED_RESULT" ]
then
  FAIL=0
fi

# Set code of 125 if LLVM failed to compile. This code tells git to "skip" this commit, as we don't know if this was actually where it broke
ONE_VAL=1
if [ "$ONE_VAL" == "$LLVM_COMPILE_FAIL" ]
then
  FAIL=125
fi

# Compute FOM
FOM=$(cat ${TEST_LOG} | grep "(inactive" | cut -d '=' -f 2 | cut -d 'p' -f 1 | cut -d ' ' -f 2 | xargs)

# Output to historical log

MACHINE_NAME=$(hostname)
TEST_TIME=$(( SECONDS - TEST_START ))

printf "%s, %s, %d, %.5f, %d, %f, %s, %d, %d\n" $CLANG_VERSION $OPENMC_VERSION $FAIL $TEST_RESULT $EXIT_CODE $FOM $MACHINE_NAME $COMPILE_TIME $TEST_TIME >> $HISTORICAL_LOG

# Return true/false code to caller based on correctness

cd $START_DIR

exit $FAIL
