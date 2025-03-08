#!/bin/bash

# Set up environment
WAVE_FILE=waves.mxd
set -e

dsim_cmd="dsim -top work.rv32i_tb -L dut +acc+b -waves $WAVE_FILE -sv_lib ../testbench/dpi/rv32i_tb.so"

sail_riscv_install_path="../TestRIG/riscv-implementations/sail-riscv/test/riscv-tests/"

# Check if a test name or hex file was given
if [ -n "$1" ]; then
  if [[ "$1" == "dii" ]]; then
    shift;
    dsim_cmd="${dsim_cmd} +dii ${@}"
  else
    test_name="$1"

    # Strip the extension from the test name if necessary
    if [[ "$test_name" == *.* ]]; then
      base_test_name="${test_name%.*}"
    else
      base_test_name="$test_name"
    fi

    # If input test name is not a file, try
    # to generate it from the sail-risv tests

    test_name_plus_ext="${base_test_name}.hex"
    if [ -f "$1" ]; then
      test_name=$1;
    elif [ -f "$test_name_plus_ext" ]; then
      test_name="$test_name_plus_ext";
    else
      # Try to generate it from the sail-risv tests
      test_name_elf="${base_test_name}.elf"

    if [[ ! -d "$sail_riscv_install_path" ]]; then
      echo "sail-riscv repo not found at $sail_riscv_install_path. Did you git init sub-repos?"
      exit 1
    fi

    # TODO, this builds all tests, add support to generate single test
    gen_test_cmd="python3 generate_riscv_tests.py ${sail_riscv_install_path}"

      eval $gen_test_cmd

      if [[ ! -f "$test_name_plus_ext" ]]; then
        echo "Neither $1 nor $test_name_plus_ext found in \$PWD, atte"
        exit 1
      fi
    fi
    dsim_cmd="$dsim_cmd +test=$base_test_name"
  fi
else
  if [[ ! -d "$sail_riscv_install_path" ]]; then
    echo "sail-riscv repo not found at $sail_riscv_install_path. Did you git init sub-repos?"
    exit 1
  fi
  gen_test_cmd="python3 generate_riscv_tests.py ${sail_riscv_install_path}"
  rm *hex || true
  eval $gen_test_cmd
  dsim_cmd="$dsim_cmd +all_tests"
fi

eval $dsim_cmd

