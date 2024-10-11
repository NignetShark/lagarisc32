import os
import logging
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteSlave, AxiLiteSlaveRead, AxiLiteReadBus

from sim_peripherals.elf_memory import *
from sim_peripherals.virtual_ns16550 import *
from sim_peripherals.halt_peripheral import *

VIRTUAL_NS16550_BASE_ADDR       = 0x1000_0000 # Same offset as QEMU
HALT_PERIPHERAL_BASE_ADDR       = 0xFFFF_FF00

@cocotb.test()
async def test_sandbox(dut):
    clk = Clock(dut.clk, 10, 'ns')
    cocotb.start_soon(clk.start())

    elf_path = cocotb.plusargs.get("elf")
    if elf_path is None:
        raise Exception("No '+elf' argument was passed. Required to load processor memory.")
    if not os.path.exists(elf_path):
        raise Exception(f"Given elf path '{elf_path}' was not found.")

    # Create a virtual memory based on a elf.
    mem = ElfMemory(elf_path)

    # Register peripherals
    peripheral_vuart   = VirtualNS16550(VIRTUAL_NS16550_BASE_ADDR, "core.stdout.txt")        # Handle CPU prints
    peripheral_halt    = HaltPeripheral(HALT_PERIPHERAL_BASE_ADDR)                          # Handle simulation aborts

    mem.register_region(peripheral_vuart,     base=VIRTUAL_NS16550_BASE_ADDR)
    mem.register_region(peripheral_halt,        base=HALT_PERIPHERAL_BASE_ADDR)

    # Create AXI4L slave that handle core accesses
    axi_inst  = AxiLiteSlaveRead(AxiLiteReadBus.from_prefix(dut, "INST_AXI"), dut.clk, dut.rst, target=mem)
    data_inst = AxiLiteSlave(AxiLiteBus.from_prefix(dut, "DATA_AXI"), dut.clk, dut.rst, target=mem)

    # Disable verbose AXI4 logs
    axi_inst.log.setLevel(logging.WARNING)
    data_inst.read_if.log.setLevel(logging.WARNING)
    data_inst.write_if.log.setLevel(logging.WARNING)

    # Prevent undefined rdata
    dut.inst_axi_rdata.value = 0xFFFF_FFFF

    # Trigger reset
    dut.rst.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
    dut.rst.value = 0

    for i in range(10):
        await RisingEdge(dut.clk)

    # Run until software stop the simulation
    await peripheral_halt.wait_until_halted()
    peripheral_vuart.close()




