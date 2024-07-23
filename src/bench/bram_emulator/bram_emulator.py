import abc
import typing
import struct
import cocotb
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.handle import ModifiableObject

class BramPorts():
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
    

class BramContent(abc.ABC):
    def __init__(self) -> None:
        pass

    @abc.abstractmethod
    def read(self, addr: int) -> int:
        pass

    @abc.abstractmethod
    def write(self, addr: int, value: int):
        pass
    
class BramWordContent(BramContent):
    def __init__(self) -> None:
        self.data = []

    def load_from_file(self, path : str):
        with open(path, 'rb') as f:
            while(1):
                word = f.read(4)
                if word:
                    self.data.append(struct.unpack("<I", word)[0])
                else:
                    return

    def read(self, addr: int) -> int:
        index = addr // 4;
        if index >= len(self.data):
            cocotb.log.info(f"Address out of range {hex(addr)}")
            return 0
        else:
            return self.data[addr // 4]
    
    def write(self, addr: int, value: int):
        self.data[addr // 4] = value


class BramEmulator:
    def __init__(self, bram_content : BramContent, clk, port_a : BramPorts, port_b : BramPorts = None) -> None:
        self.clk = clk
        self.bram_content = bram_content
        self.port_a = port_a
        self.port_b = port_b
        pass

    def start_soon(self):
        if self.port_a is not None:
            cocotb.start_soon(self.single_port_core(self.port_a))
        if self.port_b is not None:
            cocotb.start_soon(self.single_port_core(self.port_b))

    async def single_port_core(self, bram_port : BramPorts):
        while(1):
            
            last_addr   = self.port_a.read_addr()   
            last_en     = self.port_a.read_en()
            last_we     = self.port_a.read_we()
            last_din    = self.port_a.read_din()

            await RisingEdge(self.clk)

            if last_en:
                bram_port.write_dout(self.bram_content.read(last_addr))     
                if last_we:
                    self.bram_content.write(last_addr, last_din)

            await FallingEdge(self.clk)



