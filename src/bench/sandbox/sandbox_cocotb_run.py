import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteSlave, AxiLiteSlaveRead, AxiLiteReadBus

from elf_memory.elf_memory import *

@cocotb.test()
async def test_sandbox(dut):
    clk = Clock(dut.clk, 10, 'ns')
    cocotb.start_soon(clk.start())

    elf_path = cocotb.plusargs.get("elf")
    if elf_path is None:
        raise Exception("No '+elf' argument was passed. Required to load processor memory.")
    if not os.path.exists(elf_path):
        raise Exception(f"Given elf path '{elf_path}' was not found.")

    mem = ElfMemory(elf_path)

    inst_axi_slave = AxiLiteSlaveRead(AxiLiteReadBus.from_prefix(dut, "INST_AXI"), dut.clk, dut.rst, target=mem)
    data_axi_slave = AxiLiteSlave(AxiLiteBus.from_prefix(dut, "DATA_AXI"), dut.clk, dut.rst, target=mem)

    dut.inst_axi_rdata.value = 0xFFFF_FFFF

    dut.rst.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
    dut.rst.value = 0

    for i in range(10):
        await RisingEdge(dut.clk)

    await Timer(1200, 'ns')

