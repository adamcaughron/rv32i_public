import re
import argparse
import sys
import os
import glob

from parse_dump import parse_riscv_elfdump

riscv_test_dir = sys.argv[1]

all_tests = glob.glob(os.path.join(riscv_test_dir, "*.dump"))

exclude_test_patterns = [
    "-v-",
    "-amo",
    "-fadd",
    "-fm",
    "-lrsc",
    "rv64",
    "rv32mi"
]

include_test_patterns = [
    "add",
    "and",
    "aui",
    "beq",
    "bge",
    "blt",
    "bne",
    "jal",
    "-l",
    "-or",
    "-s",
    "-xor",
]


exclude_test_names = [test for excl_pattern in exclude_test_patterns for test in all_tests if excl_pattern in test]
all_tests_after_excludes = [test for test in all_tests if test not in exclude_test_names]
all_included_tests = [test for test in all_tests_after_excludes for incl in include_test_patterns if incl in test]

#print("all_tests_after_excludes:")
#for x in all_tests_after_excludes:
#    print(f"\t{x}")
#
#print("all_included_tests:")
#for x in all_included_tests:
#    print(f"\t{x}")

all_test_mem_files = []

for test in all_included_tests:
    print(f"Parsing test elfdump file {test} ...")
    if mem_file := parse_riscv_elfdump(test):
        all_test_mem_files.append(mem_file)

with open("all_riscv_tests.sv", "w") as f:
    for test in all_test_mem_files[0:-1]:
        f.write(f"\t\"{test}\",\n")
    f.write(f"\t\"{all_test_mem_files[-1]}\"\n")
