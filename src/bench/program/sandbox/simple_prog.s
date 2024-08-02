
start:
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

# li a0, -1 # i = 0
# li t0, 10 # end = 10

# while:
#    bge a0, t0, end_while
#    addi a0, a0, 1
#    j while
# end_while:

csrwi  mstatus, 0x1
csrwi  mstatus, 0x2
csrwi  mstatus, 0x3
csrrwi t0, mstatus, 0x4


