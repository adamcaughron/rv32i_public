import re
import argparse
import sys
import os
import traceback
from elftools.elf.elffile import ELFFile


def parse_riscv_elfdump(elfdump_file, skip_file_generation=False):
    elfpath, elffile = os.path.split(elfdump_file)
    base_test_name = os.path.splitext(elffile)[0]
    sv_filename = base_test_name + ".sv"
    mem_filename = base_test_name + ".hex"
    elffile_path = os.path.join(elfpath, base_test_name + ".elf")
    elfdump_path = os.path.join(elfpath, base_test_name + ".dump")

    if skip_file_generation:
        return mem_filename

    with open(mem_filename, "w") as memfile:

        with open(elffile_path, "rb") as f:
            elffile = ELFFile(f)

            for section in elffile.iter_segments():
                # if section.header.p_paddr > 0x8000_0000 and section.header.p_memsz > 0:
                memfile.write(f"@{(section.header.p_paddr - 0x8000_0000)>>2:08x}\n")

                data = section.data()
                for i in range(0, len(data), 4):
                    memfile.write(f"{data[i:i+4][::-1].hex()}\n")

    return mem_filename


if __name__ == "__main__":
    riscv_elfdump_file = sys.argv[1]
    parse_riscv_elfdump(riscv_elfdump_file)
