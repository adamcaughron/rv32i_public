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

    with open(elfdump_file, "r") as f:
        lines = f.readlines()

        while lines and not re.match(r"[0-9A-Fa-f]+ <test_2>:", lines[0]):
            lines.pop(0)

        if not lines:
            return

        try:
            test_entry_address = int(
                re.match(r"\s*([0-9A-Fa-f]+):\s+([0-9A-Fa-f]{8})", lines[1]).group(1)[
                    1:
                ],
                16,
            )
        except Exception as e:
            print("Exception in parse_riscv_elfdump...")
            print(e)
            traceback.print_stack()
            print(f"Exception parsing line:\n{lines[1]}")
            return None

        jump_to_test_offset = test_entry_address - 0x7C
        jump_to_test_instr = (jump_to_test_offset >> 1) << 21 | 0x6F

        jump_to_test = (
            f"\tmem[32'h{f"{0x7c>>2:08x}"}] = 32'h{f"{jump_to_test_instr:08x}"};\n"
        )

        if skip_file_generation:
            return mem_filename

        with open(mem_filename, "w") as memfile:
            # with open(sv_filename, "w") as testfile:
            # testfile.write(f"// {base_test_name} test:\n");
            # testfile.write("initial begin\n");
            # testfile.write(jump_to_test)

            memfile.write(f"@{0x7c>>2:08x}\n")
            memfile.write(f"{jump_to_test_instr:08x}\n")
            memfile.write(f"@{test_entry_address>>2:08x}\n")

            for line in lines:
                if m := re.match(r"([0-9A-Fa-f]+)\:\s+([0-9A-Fa-f]{8})", line):
                    # testfile.write(f"\tmem[32'h{int(m.group(1)[1:],16)>>2:08x}] = 32'h{m.group(2)};\n")

                    memfile.write(f"{m.group(2)}\n")

            with open(elffile_path, "rb") as f:
                elffile = ELFFile(f)

                for section in elffile.iter_segments():
                    if (
                        section.header.p_paddr > 0x8000_0000
                        and section.header.p_memsz > 0
                    ):
                        memfile.write(
                            f"@{(section.header.p_paddr - 0x8000_0000)>>2:08x}\n"
                        )

                        data = section.data()
                        for i in range(0, len(data), 4):
                            memfile.write(f"{data[i:i+4][::-1].hex()}\n")

            return mem_filename


if __name__ == "__main__":
    riscv_elfdump_file = sys.argv[1]
    parse_riscv_elfdump(riscv_elfdump_file)
