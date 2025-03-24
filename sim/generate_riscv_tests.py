import re
import argparse
import sys
import os
import glob

from parse_dump import parse_riscv_elfdump

# TODO: move to argparse
riscv_test_dir = sys.argv[-1]
skip_parsing = sys.argv[-2] == "--filelist-only"

all_tests = glob.glob(os.path.join(riscv_test_dir, "*.elf"))

exclude_test_patterns = [
    "-v-",
    "-amo",
    "-fadd",
    "-fm",
    "-lrsc",
    "rv64",
    "rv32si-p-dirty",
]

include_test_patterns = ["rv32ui", "rv32mi", "rv32si"]

exclude_test_names = [
    test
    for excl_pattern in exclude_test_patterns
    for test in all_tests
    if excl_pattern in test
]
all_tests_after_excludes = [
    test for test in all_tests if test not in exclude_test_names
]
all_included_tests = [
    test
    for test in all_tests_after_excludes
    for incl in include_test_patterns
    if incl in test
]

# print("all_tests_after_excludes:")
# for x in all_tests_after_excludes:
#    print(f"\t{x}")
#
# print("all_included_tests:")
# for x in all_included_tests:
#    print(f"\t{x}")

all_test_mem_files = []

for test in all_included_tests:
    if not skip_parsing:
        print(f"Parsing test elfdump file {test} ...")
    if mem_file := parse_riscv_elfdump(test, skip_parsing):
        all_test_mem_files.append(mem_file)

with open("all_riscv_tests.sv", "w") as f:
    if all_test_mem_files:
        for test in all_test_mem_files[0:-1]:
            f.write(f'\t"{test}",\n')
        f.write(f'\t"{all_test_mem_files[-1]}"\n')
    else:
        print(
            f"Warning! No tests were generated! Is your sail-riscv repo initialized ({riscv_test_dir})?"
        )
