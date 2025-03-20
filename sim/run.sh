#!/bin/bash

# Set up environment
WAVE_FILE=waves.vcd
set -e

dsim_cmd="dsim -top work.rv32i_tb -L dut +acc+b -waves $WAVE_FILE -sv_lib ../testbench/dpi/rv32i_tb.so"

sail_riscv_install_path="../TestRIG/riscv-implementations/sail-riscv/test/riscv-tests/"

# Check if a test name or hex file was given
if [ -n "$1" ]; then
  if [[ "$1" == "dii" ]]; then
    shift;
    dsim_cmd="${dsim_cmd} +dii ${@}"
  elif [[ "$1" == "all_tests" ]]; then
    shift;
    dsim_cmd="$dsim_cmd +all_tests ${@}"
  elif [[ "$1" == "+rvfi_ext" ]]; then
    dsim_cmd="$dsim_cmd +all_tests ${@}"
  else
    testname=$1
    shift
    dsim_cmd="$dsim_cmd +test=${testname} ${@}"
  fi
else
  if [[ ! -d "$sail_riscv_install_path" ]]; then
    echo "sail-riscv repo not found at $sail_riscv_install_path. Did you git init sub-repos?"
    exit 1
  fi
  dsim_cmd="$dsim_cmd +all_tests"
fi

echo $dsim_cmd
eval $dsim_cmd

