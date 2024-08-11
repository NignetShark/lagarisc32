import abc
import typing
import struct
import cocotb
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.handle import ModifiableObject, BinaryValue
from cocotbext.axi.address_space import MemoryInterface


class BramPorts:
    def __init__(self, addr: ModifiableObject, din, dout, en, we) -> None:
        self.addr = addr
        self.din = din
        self.dout = dout
        self.we = we
        self.en = en

    def read_addr(self):
        if self.addr.value.is_resolvable:
            return self.addr.value
        else:
            return 0

    def read_din(self):
        return self.din.value if self.din is not None else 0

    def write_dout(self, value):
        if self.dout is not None:
            self.dout.value = value

    def read_en(self):
        return self.en.value if self.din is not None else 1

    def read_we(self):
        return self.we.value if self.we is not None else 0

    @staticmethod
    def from_prefix(parent, suffix : str, with_din : bool = False, with_we : bool = False):
        addr = parent._id(f"{suffix}_addr")
        din  = parent._id(f"{suffix}_din") if with_din else None
        dout = parent._id(f"{suffix}_dout")
        en   = parent._id(f"{suffix}_en")
        we   = parent._id(f"{suffix}_we") if with_we else None
        return BramPorts(addr, din, dout, en, we)

class BramEmulator:
    def __init__(self, mem_itf : MemoryInterface, clk, port_a : BramPorts, port_b : BramPorts = None) -> None:
        self.clk = clk
        self.mem_itf = mem_itf
        self.port_a = port_a
        self.port_b = port_b

    def start_soon(self):
        if self.port_a is not None:
            cocotb.start_soon(self.single_port_core(self.port_a))
        if self.port_b is not None:
            cocotb.start_soon(self.single_port_core(self.port_b))

    async def single_port_core(self, bram_port : BramPorts):
        while(1):

            last_addr   = int(bram_port.read_addr())
            last_en     = int(bram_port.read_en())
            last_we     = int(bram_port.read_we())
            last_din    = int(bram_port.read_din())

            await RisingEdge(self.clk)

            if last_en:

                try:
                    bram_port.write_dout(await self.mem_itf.read_dword(last_addr))
                except:
                    cocotb.log.warning(f"BRAM access out of range (address: {hex(last_addr)})")
                    bram_port.write_dout(0)

                if last_we:
                    await self.mem_itf.write_dword(last_addr, last_din)

            await FallingEdge(self.clk)




