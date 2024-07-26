import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from bram_emulator.bram_emulator import *

@cocotb.test()
async def test_fetch(dut):
    clk = Clock(dut.clk, 10, 'ns')
    cocotb.start_soon(clk.start())

    bram_content = BramWordContent()
    bram_content.load_from_file("program/sandbox/simple_prog.bin")

    bram = BramEmulator(bram_content, dut.clk, BramPorts(dut.bram_addr, None, dut.bram_dout, dut.bram_en, None))
    bram.start_soon()

    dut.rst.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    #dut.fetch_en.value = 1

    for i in range(10):
        await RisingEdge(dut.clk)

    #dut.fetch_en.value = 0
    await Timer(1200, 'ns')

