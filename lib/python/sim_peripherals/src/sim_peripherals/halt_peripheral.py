import os
import cocotb
import struct
import binascii
from cocotb.triggers import Event
from cocotbext.axi.address_space import MemoryInterface

from sim_peripherals.elf_memory import *

HALT_PERIPHERAL_START_SIG_OFFSET = 0x0
HALT_PERIPHERAL_END_SIG_OFFSET   = 0x4
HALT_PERIPHERAL_HALT_OFFSET      = 0x8

class HaltPeripheral(MemoryInterface):
    def __init__(self, base : int, signature_path : str = None):
        super().__init__(size = 4 * 3, base = base)
        self.signature_path = signature_path
        self.processor_halt_event  = Event("Processor halted")

        self.start_sign_addr = 0x0
        self.end_sign_addr   = 0x0

    async def _read(self, address, length, **kwargs):
        raise Exception("Halt must be a write access")

    async def _write(self, address, data, **kwargs):
        if address == HALT_PERIPHERAL_START_SIG_OFFSET:
            self.start_sign_addr = struct.unpack("<I", data)[0]
        elif address == HALT_PERIPHERAL_END_SIG_OFFSET:
            self.end_sign_addr = struct.unpack("<I", data)[0]
        elif address == HALT_PERIPHERAL_HALT_OFFSET:
            await self.dump_signature()
            self.processor_halt_event.set()

    async def dump_signature(self):
        if self.signature_path is None:
            return # No signature dump.

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