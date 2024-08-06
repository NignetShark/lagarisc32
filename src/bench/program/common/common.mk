AS = riscv64-unknown-elf-as
LD = riscv64-unknown-elf-ld
CC = riscv64-unknown-elf-gcc

OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump
CFLAGS = -march=rv32ima -mabi=ilp32
LDFLAGS = -melf32lriscv

LD_SCRIPT = ../common/dummy_mem.ld

%.o: %.s $(DEPS)
	$(AS) -o $@ -c $< $(CFLAGS)

%.o: %.c $(DEPS)
	$(CC) -o $@ -c $< $(CFLAGS)

%.elf : %.o
	$(LD) -o $@ -T $(LD_SCRIPT) $< $(LDFLAGS)

%.bin : %.elf
	$(OBJCOPY) -O binary $< $@

%.txt : %.elf
	$(OBJDUMP) -D $< > $@