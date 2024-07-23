# Makefile

# defaults
SIM ?= questa
TOPLEVEL_LANG ?= vhdl

VHDL_LIB_ORDER = lagarisc

HDL_SRC = $(PWD)/../hdl
VHDL_SOURCES_lagarisc += ${HDL_SRC}/pkg_lagarisc.vhd
VHDL_SOURCES_lagarisc += $(wildcard ${HDL_SRC}/*.vhd)
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL_LIBRARY 	= lagarisc
TOPLEVEL 			= lagarisc_core

# MODULE is the basename of the Python test file
MODULE = test_fetch_bram

SCRIPT_FILE = setup_script_file.do

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim



