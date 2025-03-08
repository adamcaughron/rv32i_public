RV32I Processor and Testbench
=============================

This repository contains a simple, single-cycle [RV32I](https://lf-riscv.atlassian.net/wiki/spaces/HOME/pages/16154769/RISC-V+Technical+Specifications#ISA-Specifications) SystemVerilog behavioral model, along with a testbench and automation scripts.

It is intended as a starting point for experiments with CPU and testbench development activities, for education or fun.

The core currently supports the following features:
- RV32I base ISA, v2.1
- Zicsr extension for CSR instructions, v2.0
- Partial support for RISCV privileged architecture
  - Machine ISA, v1.13, partial support
  - Supervisor ISA, v1.13, partial support

The testbench supports the following modes of operation:
- Execution of elf files via conversion to backdoor-loadable initialization files
- [RVFI-DII](https://github.com/CTSRD-CHERI/TestRIG/blob/master/RVFI-DII.md) (RISC-V Formal Interface - Direct Instruction Injection) random instruction streams and comparison against [sail-riscv](https://github.com/riscv/sail-riscv/tree/master) ISA simulator via integration with [TestRIG](https://github.com/CTSRD-CHERI/TestRIG/tree/master)

Verification status:
- Many of the self-checking tests from the [sail-riscv](https://github.com/riscv/sail-riscv/tree/master/test/riscv-tests) repo are passing:
  - All 39 `"rv32ui-p-*"` tests are passing
  - The following `"rv32mi-p-*"` tests are passing: `rv32mi-p-csr, rv32mi-p-ma_addr, rv32mi-p-sbreak, rv32mi-p-scall, rv32mi-p-shamt`
  - The following `"rv32si-p-*"` tests are passing: `rv32si-p-csr, rv32si-p-sbreak, rv32si-p-scall`
- Tens of thousands of random instruction streams match against the `sail-riscv` reference model via testing with `TestRIG` and `QCVengine` generator

Getting Started
---------------

### Prerequesites
This project should work with any IEEE1800-compliant SytemVerilog simulator, but the scripts assume the use of [Altair DSim](https://altair.com/dsim)<sup>(tm)</sup>. Sign up for an Altair One account and install DSim and a license file per the [Getting Started Guide](https://learn.altair.com/course/view.php?id=810).

This repo provides the `TestRIG` repo as a submodule, which in turn provides several other repos, like `sail-riscv`, which provides the self-checking tests and an ISA simulator. To initialize the subrepos, after cloning this repo, do:

```sh
$ git submodule update --init --recursive
```

#### Installing TestRIG
The following steps are required in order to run RVFI-DII mode, where random instruction streams are executed and checked against the `sail-riscv` ISA simulator. These steps are not needed if you are only running elf-based tests.

To install TestRIG and its dependencies, follow the [Getting Started](https://github.com/CTSRD-CHERI/TestRIG?tab=readme-ov-file#getting-started) instructions in the `TestRIG` repo. You will need to install dependencies *at least* for building the `sail-riscv` simulator and the Quick Check Verification Engine. This will require [GHCup](https://www.haskell.org/ghcup/), [opam](https://opam.ocaml.org/doc/Install.html), [cabal](https://www.haskell.org/cabal/), and [sail](https://opam.ocaml.org/packages/sail/), and their dependencies.

The git repos for those respective projects have valuable information for, specifically [How to install Sail using opam](https://github.com/rems-project/sail/blob/sail2/INSTALL.md#how-to-install-sail-using-opam) in the `sail` repo and [Building the model](https://github.com/riscv/sail-riscv/tree/master?tab=readme-ov-file#building-the-model) in the `sail-riscv` repo.

You are ready to proceed once you can build and run the "[Default Configuration](https://github.com/CTSRD-CHERI/TestRIG?tab=readme-ov-file#default-configuration)" example in the `TestRIG` directory:
```sh
$ make
$ utils/scripts/runTestRIG.py
```

Note, the above instructions from the TestRIG repo build some things which this repo doesn't use. The `make` command can be ammended as follows to build fewer targets, but the `runTestRIG.py` command should still pass before proceeding: 
```sh
$ make vengines sail
$ utils/scripts/runTestRIG.py
```

Compiling and Running
---------------------
### Environment Setup
Configure your shell for the DSim environment. Usually, this entails something like:
```sh
$ export DSIM_LICENSE=~/metrics-ca/dsim-license.json
$ source $DSIM_HOME/2025/shell_activate.bash
```
Though the path to the license file and the value of `$DSIM_HOME` will depend on your installation. Refer to the [DSim User Manual](https://help.metrics.ca/support/solutions/articles/154000141193-user-guide-dsim-user-manual) for help.


### Build & Run
Building the model and running simulations is done from the `sim` directory.

To run the self-checking tests from the `sail-riscv` repo:
```sh
$ ./compile_and_run.sh
```

To run a specific test:
```sh
$ ./compile_and_run.sh <test_name[.hex]>
```

To run random instruction streams in RVFI-DII mode, you will need two shells -- one to run DSim, and another to run TestRIG.
In the first shell, set up the DSim environment and run (from the sim directory):
```sh
$ ./compile_and_run.sh dii
```
You will see a message like the following. Note the port number (which will likely differ):
```
rvfi_dii_server_thread: Ready for client to connect on port 47889...
```
In the second shell, from the TestRIG directory, run the following, substituting the port number from your DSim run:
```sh
$ utils/scripts/runTestRIG.py -b manual --implementation-B-port 47889
```

### Testbench plusargs
These are the SV plusargs supported by the testbench. These are useful if you edit `run.sh` or invoke `dsim` directly.
|Plusarg              |Description                                                                      |
|---------------------|---------------------------------------------------------------------------------|
|+test=\<test\_name\> | For running a single test. Specified with or without '.hex' extension           |
|+all\_tests          | Run all tests listed in `all_riscv_tests.sv` at elaboration time                |
|+dii                 | Run the testbench in RVFI-DII mode. (Will wait for incoming socket connection.) |
|+portnum             | For use with +dii, to specify the port for the RVFI-DII engine to connect to.   |

