RV32I Processor and Testbench
=============================

This repository contains a simple, single-cycle [RV32I](https://lf-riscv.atlassian.net/wiki/spaces/HOME/pages/16154769/RISC-V+Technical+Specifications#ISA-Specifications) SystemVerilog behavioral model, along with a testbench and automation scripts.

It is intended as a starting point for experiments with CPU and testbench development activities, for education or fun.

The core currently supports the following features:
- RV32I base ISA, v2.1
 
The testbench supports the following modes of operation:
- Execution of ".dump" files via conversion to backdoor-loadable initialization files

Verification status:
- 37 out of 39 of the self-checking tests from the [sail-riscv](https://github.com/riscv/sail-riscv/tree/master/test/riscv-tests) repo are passing:

Getting Started
---------------

### Prerequesites
This project should work with any IEEE1800-compliant SytemVerilog simulator, but the scripts assume the use of [Altair DSim](https://altair.com/dsim)<sup>(tm)</sup>. Sign up for an Altair One account and install DSim and a license file per the [Getting Started Guide](https://learn.altair.com/course/view.php?id=810).

This repo provides the `TestRIG` repo as a submodule, which in turn provides several other repos, like `sail-riscv`, which provides the self-checking tests and an ISA simulator. To initialize the subrepos, after cloning this repo, do:

```sh
$ git submodule update --init --recursive
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

### Testbench plusargs
These are the SV plusargs supported by the testbench. These are useful if you edit `run.sh` or invoke `dsim` directly.
|Plusarg              |Description                                                             |
|---------------------|------------------------------------------------------------------------|
|+test=\<test\_name\> | For running a single test. Specified with or without '.hex' extension  |
|+all\_tests           | Run all tests listed in `all_riscv_tests.sv` at elaboration time       |
