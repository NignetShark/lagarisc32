import os
import cocotb
import struct
import binascii
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, Event
from cocotbext.axi import AxiLiteBus, AxiLiteSlave, AxiLiteSlaveRead, AxiLiteReadBus
from cocotbext.axi.address_space import MemoryInterface

from elf_memory.elf_memory import *

HALT_PERIPHERAL_ADDR             = 0xFFFF_FF00
HALT_PERIPHERAL_START_SIG_OFFSET = 0x0
HALT_PERIPHERAL_END_SIG_OFFSET   = 0x4
HALT_PERIPHERAL_HALT_OFFSET      = 0x8

class HaltPeripheral(MemoryInterface):
    def __init__(self, base : int, signature_path : str):
        super().__init__(size = 4 * 3, base = base)
        self.signature_path = signature_path
        self.processor_halt_event  = Event("Processor halted")

        self.start_sign_addr = 0x0
        self.end_sign_addr   = 0x0

    async def _read(self, address, length, **kwargs):
        raise Exception("Halt must be a write access")

    async def _write(self, address, data, **kwargs):
        cocotb.log.warning(f"Halt processor access addr:{address}; data:{data}")

        if address == HALT_PERIPHERAL_START_SIG_OFFSET:
            self.start_sign_addr = struct.unpack("<I", data)[0]
        elif address == HALT_PERIPHERAL_END_SIG_OFFSET:
            self.end_sign_addr = struct.unpack("<I", data)[0]
        elif address == HALT_PERIPHERAL_HALT_OFFSET:
            await self.dump_signature()
            self.processor_halt_event.set()

    async def dump_signature(self):
        cocotb.log.info(f"Dumping signature from {hex(self.start_sign_addr)} to {hex(self.end_sign_addr)}")
        try:
            with open(self.signature_path, "w") as file:
                for addr in range(self.start_sign_addr, self.end_sign_addr, 4):
                    dword = await self.parent.read(address=addr, length=4)
                    file.write(binascii.hexlify(dword[::-1]).decode("ascii") + "\n")
        except Exception as e:
            print(e)


    async def wait_until_halted(self):
        self.processor_halt_event.clear()
        await self.processor_halt_event.wait()
        self.processor_halt_event.clear()

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
    halt = HaltPeripheral(HALT_PERIPHERAL_ADDR, sig_path)

    # Memory loaded from elf.
    mem = ElfMemory(elf_path)
    mem.register_region(halt, base=HALT_PERIPHERAL_ADDR) # Add peripheral to mmap.

    # ======================================
    # == Bind to AXI interfaces
    # ======================================
    inst_axi_slave = AxiLiteSlaveRead(AxiLiteReadBus.from_prefix(dut, "INST_AXI"), dut.clk, dut.rst, target=mem)
    data_axi_slave = AxiLiteSlave(AxiLiteBus.from_prefix(dut, "DATA_AXI"), dut.clk, dut.rst, target=mem)

    dut.inst_axi_rdata.value = 0xFFFF_FFFF

    # ======================================
    # == Running test
    # ======================================

    cocotb.log.info(f"Triggering reset.")

    dut.rst.value = 1
    for i in range(10):
        await RisingEdge(dut.clk)
    dut.rst.value = 0

    for i in range(10):
        await RisingEdge(dut.clk)

    cocotb.log.info(f"Running processor until halt request.")
    await halt.wait_until_halted()
    cocotb.log.info(f"Processor halted. Signatured dumped to {sig_path}.")

