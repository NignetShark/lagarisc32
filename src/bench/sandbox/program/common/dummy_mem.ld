
OUTPUT_ARCH("riscv")

ENTRY( _start )

MEMORY
{
    ram (wxa) : ORIGIN = 0x80000000, LENGTH = 0x30000 /* 192 kB */
}

/* Stack information variables */
_min_stack      = 0x2000;   /* 8K - minimum stack space to reserve */

SECTIONS
{
    .text : {
        /* Boot instructions before main application */
        *(.text.boot)
        *(.text .text.*)
    } > ram

    PROVIDE(_global_pointer = .);

    .rodata : {
        . = ALIGN(4);
        /* Small RO data before large RO data */
        *(.srodata)
        *(.srodata.*)
        *(.rodata);
        *(.rodata.*)
    } > ram

    .data : {
        . = ALIGN(4);
        /* Small data before large data */
        *(.sdata)
        *(.sdata.*)
        *(.data);
        *(.data.*)
    } > ram

    .bss : {
        . = ALIGN(4);
        PROVIDE(_bss_start = .);
        /* Small BSS before large BSS */
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        PROVIDE(_bss_end = .);
    } > ram

    .eh_frame : {
        *(.eh_frame)
    } > ram

    .stack (NOLOAD): {
        . = ALIGN(4);
        PROVIDE(_stack_start = .);
        . = . + _min_stack;
        . = ALIGN(4);
        PROVIDE(_stack_end = .);
    } > ram
}

