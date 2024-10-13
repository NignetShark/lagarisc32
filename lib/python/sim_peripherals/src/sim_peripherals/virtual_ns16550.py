import enum
import cocotb
import struct
from cocotbext.axi.address_space import MemoryInterface

class UartRegOffset(enum.Enum):
    RX_TX       = 0x0
    IRQ_EN      = 0x1
    IRQ_ST      = 0x2
    FIFO_CTRL   = 0x3
    LINE_CTRL   = 0x4
    MODEM_CTRL  = 0x5
    LINE_ST     = 0x6
    MODEM_ST    = 0x7
    SCRATCH_PAD = 0x8

class VirtualNS16550(MemoryInterface):
    def __init__(self, base, stdout_path = None, **kwargs):
        super().__init__(size=8, base=base, **kwargs)
        self.log = cocotb.log.getChild("core_stdout")
        self.fifo_tx = ""
        self.fifo_rx = ""

        self.reg_space = {k : 0 for k in UartRegOffset}

        if stdout_path:
            self.file = open(stdout_path, "w")
        else:
            self.file = None

    def _read(self, address, length, **kwargs):
        ret_value = 0

        if address in UartRegOffset:
            if address == UartRegOffset.RX_TX.value:
                if len(self.fifo_rx) > 0:
                    char = self.fifo_rx[0]
                    self.fifo_rx = self.fifo_rx[1:]
                    return char.encode('ascii')
                else:
                    return b'0'
            elif address == UartRegOffset.LINE_ST.value:
                ret_value = self.reg_space[UartRegOffset.LINE_ST]

                # Set Data Ready flag
                ret_value &= 0xFE
                ret_value |= (len(self.fifo_rx) > 0)
            else: # Dummy register behavior
                ret_value = self.reg_space[UartRegOffset(address)]

        return struct.pack("<B", ret_value)


    def _write(self, address, data, **kwargs):
        self.log.info(f"Writing to UART (addr = {hex(address)}) !")
        if address not in UartRegOffset:
            self.log.warning(f"Unknown access at {hex(address)}.")
            return

        if address == UartRegOffset.RX_TX.value:
            if self.reg_space[UartRegOffset.LINE_CTRL] & (1 << 7):
                pass # DLAB enabled (ignore value)
            else:
                # Add character to FIFO
                self.putchar(data.decode("ascii")[0])
        else:
            # Write register
            self.reg_space[address] = int(data[0])

    def putchar(self, char: str):
        if char == '\n':
            self.flush()
        else:
            self.log.debug(f"Putting char in fifo : '{char}'")
            self.fifo_tx += char

    def flush(self):
        self.log.info(self.fifo_tx)
        if self.file:
            self.log.info(f"Uart: {self.fifo_tx}")
            self.file.write(self.fifo_tx + "\n")
        self.fifo_tx = ""

    def close(self):
        if self.file:
            self.file.close()
