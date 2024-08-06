from elftools.elf.elffile import ELFFile
from elftools.elf.sections import Section
from elftools.elf.constants import SH_FLAGS
import cocotb
from cocotbext.axi.address_space import AddressSpace, Region

class ElfSectionRegion(Region):
    def __init__(self, section : Section) -> None:
        super().__init__(size=section['sh_size'], base=section['sh_addr'])
        self.name = section.name
        self.is_writable = section['sh_flags'] & SH_FLAGS.SHF_WRITE
        self.data = bytearray(section.data())

    async def _read(self, address, length, **kwargs):

        return self.data[address:address+length]

    async def _write(self, address, data, **kwargs):
        #if self.is_writable:
        cocotb.log.info(f"Writing @{hex(self.base)} + {hex(address)}")
        self.data[address:address+len(data)] = data
        #else:
        #    raise Exception(f"Section {self.name} is not writable (Write attempt at {hex(self.base + address)})")

class ElfMemory(AddressSpace):
    def __init__(self, elf_path):
        super().__init__(size=2**32, base=0, parent=None)

        with open(elf_path, 'rb') as file_handler:
            elf_file = ELFFile(file_handler)
            for section in elf_file.iter_sections():
                if section.is_null():
                    continue
                if section['sh_flags'] & SH_FLAGS.SHF_ALLOC:
                    elf_region = ElfSectionRegion(section)
                    self.register_region(elf_region, base=elf_region.base)
