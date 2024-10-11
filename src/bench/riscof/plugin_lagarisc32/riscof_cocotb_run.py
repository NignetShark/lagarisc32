import os
import cocotb
import struct
import binascii
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, Event
from cocotbext.axi import AxiLiteBus, AxiLiteSlave, AxiLiteSlaveRead, AxiLiteReadBus
from cocotbext.axi.address_space import MemoryInterface

from sim_peripherals.elf_memory import *
from sim_peripherals.halt_peripheral import *

HALT_PERIPHERAL_BASE_ADDR             = 0xFFFF_FF00

@cocotb.test()
async def riscof_run(dut):
    # ======================================
    # == Check arguments
    # ======================================
    elf_path = cocotb.plusargs.get("elf")
    if elf_path is None:
        raise Exception("No '+elf' argument was passed. Required to load processor memory.")
    if not os.path.exists(elf_path):
        raise Exception(f"Given elf path '{elf_path}' was not found.")


    sig_path = cocotb.plusargs.get("sig")
    if sig_path is None:
        raise Exception("No '+sig' argument was passed. Required to dump signature.")

    # ======================================
    # == Basic simulation components
    # ======================================

    clk = Clock(dut.clk, 10, 'ns')
    cocotb.start_soon(clk.start())

    # ======================================
    # == Generate memory mapping
    # ======================================
    # Peripheral that handle software halt requests and dump signature.
    halt = HaltPeripheral(HALT_PERIPHERAL_BASE_ADDR, sig_path)

    # Memory loaded from elf.
    mem = ElfMemory(elf_path)
    mem.register_region(halt, base=HALT_PERIPHERAL_BASE_ADDR) # Add peripheral to mmap.

    # ======================================
    # == Bind to AXI interfaces
    # ======================================
    inst_axi_slave = AxiLiteSlaveRead(AxiLiteReadBus.from_prefix(dut, "INST_AXI"), dut.clk, dut.rst, target=mem)
    data_axi_slave = AxiLiteSlave(AxiLiteBus.from_prefix(dut, "DATA_AXI"), dut.clk, dut.rst, target=mem)

    dut.inst_axi_rdata.value = 0xFFFF_FFFF # prevent Modelsim exception (=> integer exception on register id (not used))

    # ======================================
    # == Running test
    # ======================================
    dut.rst.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
    dut.rst.value = 0

    for i in range(10):
        await RisingEdge(dut.clk)

    cocotb.log.info(f"Running processor until halt request.")
    await halt.wait_until_halted()
    cocotb.log.info(f"Processor halted. Signature dumped to {sig_path}.")

