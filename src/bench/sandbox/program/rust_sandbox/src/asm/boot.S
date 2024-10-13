.option norvc

.section .text.boot
.global _start
_start:

    # Set global pointer
.option push
.option norelax
	la		gp, _global_pointer
.option pop

	# Clear BSS section
	la 		a0, _bss_start
	la		a1, _bss_end
	bgeu	a0, a1, _bss_break

_bss_clear:
	sw		zero, (a0)
	addi	a0, a0, 8
	bltu	a0, a1, _bss_clear

_bss_break:

    # Load stack pointer
    la		sp, _stack_end

    # Set return address if main returns
    la		ra, _abort_sim
    j 		main

_abort_sim:
    la  t0, 0xFFFFFF08 	# Halt address for Questasim
    li  t1, 0xDEADDEAD
    sw  t1, 0(t0)		# Simulation should stop.

_cpu_park:
	wfi
	j	_cpu_park
