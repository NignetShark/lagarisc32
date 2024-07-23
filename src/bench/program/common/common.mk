AS = riscv64-unknown-elf-as
LD = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

LD_SCRIPT = ../common/dummy_mem.ld

%.o: %.s $(DEPS)
	$(AS) -o $@ $< $(CFLAGS)

%.elf : %.o
	$(LD) -o $@ -T $(LD_SCRIPT) $< $(CFLAGS)

%.bin : %.elf
	$(OBJCOPY) -O binary $< $@

%.txt : %.elf
	$(OBJDUMP) -D $< > $@