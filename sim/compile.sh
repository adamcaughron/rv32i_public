#!/bin/bash

set -e


if [ ! -n "$1" ]; then
  # Currently, the full test list in a generated .sv file (all_riscv_tests.sv), so need to generate it prior to elaboration for now.
  # The test collateral (.hex files) will be generated at runtime, due to the "--filelist-only" switch below
  sail_riscv_install_path="../TestRIG/riscv-implementations/sail-riscv/test/riscv-tests/"

  if [[ ! -d "$sail_riscv_install_path" ]]; then
    echo "sail-riscv repo not found at $sail_riscv_install_path. Did you git init sub-repos?"
    exit 1
  fi
  gen_test_cmd="python3 generate_riscv_tests.py --filelist-only ${sail_riscv_install_path}"
  eval $gen_test_cmd
fi


# This script is called "compile.sh" but it's really just
# "elaborate.sh" ... compile is currently done by dsim as
# part of "run.sh"

# Compile standard libraries
dlib rm -lib ieee || true
dlib map -lib ieee ${STD_LIBS}/ieee93 || true

# Analyze separately, Elaborate and Run in one step.
dvlcom -lib dut -sv -F filelist.txt
dvlcom ../testbench/rv32i_tb.sv ../testbench/rv32i_dii.sv

# Build TB SO file:
(cd ../testbench/dpi && make all)
