.option norvc

.section .text.boot
.global _start
_start:

# li t0, 3
# srli t0, t0, 1
# li t1, 1
# li t2, 2
# j start
# addi t0, t0, 1;
# j start

# li t1, 3
# li t1, 4
# li t1, 5
# li t1, 6
# li t1, 7

# test:
# li t0, 1

# li a0, 0 # i = 0
# li t0, 10 # end = 10

# while:
#    bge a0, t0, end_while
#    addi a0, a0, 1
#    j while
# end_while:

# li t1, 3
# li t1, 4

# csrwi  mstatus, 0x1
# csrwi  mstatus, 0x2
# csrwi  mstatus, 0x3
# csrrwi t0, mstatus, 0x4
# li t0, 0
# ld t1, 0(t0) #

# li t2, 0xABCD
# sw t2, 0(t0) #
# lw t3, 0(t0) #
# lw t4, 0(t0) #
# lw t5, 0(t0) #

################

la sp, _stack_start
li a0, 0
li a1, 1
li a2, 2

sw sp, 0(sp) # 0x8000_0024 <- 0x8000_0024
lw a1, 0(sp) # a1 <- 0x8000_0024
sw a2, 0(a1) # 0x8000_0024 <- 2
lw a0, 0(a1) # a0 <- 2


# #######

# # Print 'hello'
# la a0, 0xFFFF0000

# li t0, 0x68
# sb t0, 0(a0)

# li t0, 0x65
# sb t0, 0(a0)

# li t0, 0x6c
# sb t0, 0(a0)

# li t0, 0x6c
# sb t0, 0(a0)

# li t0, 0x6f
# sb t0, 0(a0)

# li t0, 0x0a
# sb t0, 0(a0)

# Abort simulation
la a0, 0xFFFFFF00
li t0, 0xDEADDEAD
sw t0, 8(a0)