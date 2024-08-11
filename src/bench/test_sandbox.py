import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteSlave, AxiLiteSlaveRead, AxiLiteReadBus

from elf_emulator.elf_memory import *
from bram_emulator.bram_emulator import *

@cocotb.test()
async def test_fetch(dut):
    clk = Clock(dut.clk, 10, 'ns')
    cocotb.start_soon(clk.start())


    mem = ElfMemory("program/asm_sandbox/simple_prog.elf")

    # bram = BramEmulator(mem, dut.clk, BramPorts.from_prefix(dut, "inst_bram"))
    # bram.start_soon()

    inst_axi_slave = AxiLiteSlaveRead(AxiLiteReadBus.from_prefix(dut, "INST_AXI"), dut.clk, dut.rst, target=mem)
    data_axi_slave = AxiLiteSlave(AxiLiteBus.from_prefix(dut, "DATA_AXI"), dut.clk, dut.rst, target=mem)

    dut.inst_axi_rdata.value = 0xFFFF_FFFF

    dut.rst.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    #dut.fetch_en.value = 1

    for i in range(10):
        await RisingEdge(dut.clk)

    #dut.fetch_en.value = 0
    await Timer(1200, 'ns')

