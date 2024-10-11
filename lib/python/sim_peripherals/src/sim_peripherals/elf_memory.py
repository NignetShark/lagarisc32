from elftools.elf.elffile import ELFFile
from elftools.elf.sections import Section
from elftools.elf.constants import SH_FLAGS
import logging
import cocotb
import binascii
from cocotbext.axi.address_space import AddressSpace, Region

class ElfSectionRegion(Region):
    def __init__(self, parent_log: logging.Logger, section : Section) -> None:
        super().__init__(size=section['sh_size'], base=section['sh_addr'])
        self.name = section.name
        self.log = parent_log.getChild(self.name)
        self.is_writable = section['sh_flags'] & SH_FLAGS.SHF_WRITE
        self.data = bytearray(section.data())

    async def _read(self, address, length, **kwargs):
        data = self.data[address:address+length]
        self.log.debug(f"Reading: {hex(self.base + address)} : 0x{binascii.hexlify(data).decode("ascii")}")
        return data

    async def _write(self, address, data, **kwargs):
        #if self.is_writable:
        self.log.info(f"Writing: {hex(self.base + address)} : 0x{binascii.hexlify(data).decode("ascii")}")
        self.data[address:address+len(data)] = data
        #else:
        #    raise Exception(f"Section {self.name} is not writable (Write attempt at {hex(self.base + address)})")

class ElfMemory(AddressSpace):
    def __init__(self, elf_path):
        super().__init__(size=2**32, base=0, parent=None)

        self.log = cocotb.log.getChild("elf_mem")

        self.log.info(f"****** ELF Memory loaded ({elf_path}) ******")

        with open(elf_path, 'rb') as file_handler:
            elf_file = ELFFile(file_handler)

            for section in elf_file.iter_sections():

                if section.is_null():
                    continue

                if section['sh_flags'] & SH_FLAGS.SHF_ALLOC:
                    elf_region = ElfSectionRegion(self.log, section)
                    self.register_region(elf_region, base=elf_region.base)
                    self.log.info(f"* {section.name:10} - base: 0x{hex(section['sh_addr'])}, size:{section['sh_size']}.")
                else:
                    self.log.info(f"* {section.name:10} - not loaded.")

        self.log.info(f"************")

