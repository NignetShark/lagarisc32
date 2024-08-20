# LagaRISC32
LagaRISC32 is a class of **5-stage pipeline** core written in VHDL. The main purpose of this project is to target a **FPGA implementation**. Currently the CPU support only **RV32I** with **AXI4-Lite** interface.

## Ressources
|Target                      | LUT  | FF   | F test |
|----------------------------|------|------|--------|
|Kintex 7 - xc7k160tffg979-3 | 1800 | 2100 | 200 MHz|

## Bench
The bench use the [RISCOF framework](https://github.com/riscv-software-src/riscof) to check the compliance against [Spike](https://github.com/riscv-software-src/riscv-isa-sim). The bench use assembly programs from [riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test) which are executed by the core. The execution generate signatures that are compared with Spike ones.

Currently the 39/39 tests from RV32I passed. Note: FENCE test pass but it's still not supported.

The simulation use Python to interact with VHDL using [cocotb](https://github.com/cocotb/cocotb). The AXI4L support is handled by [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi) that provide a virtual memory space to interact with. Since RISCOF generate ELF files, I have crafted my own library to map ELF files to the virtual memory. I have also added a virtual peripheral that can halt the simulation on software requests and can dump the signature into a file.

The current CocoTB settings use ModelSim as the main simulator but it should be easy to change to another simulator like GHDL (not tested).

## Limitations
* Interruptions/exceptions are not yet implemented.
* CSR not yet implemented (in progress in order to support interruptions).
* FENCE instruction is not supported.
* Privileged execution is not supported (no user/supervisor/hypervisor mode).