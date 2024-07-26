library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_wb is
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        -- ==== > MEM ====
        -- PC
        MEM_PC_NOT_TAKEN        : in std_logic_vector(31 downto 0);
        -- RD
        MEM_RD_ID               : in std_logic_vector(4 downto 0);
        MEM_RD_WE               : in std_logic;
        -- ALU
        MEM_ALU_RESULT          : in std_logic_vector(31 downto 0);
        -- MEM
        MEM_MEM_DOUT            : in std_logic_vector(31 downto 0);
        MEM_MEM_WE              : in std_logic;
        -- WB
        MEM_WB_MUX              : in mux_wb_src_t;

        -- ==== DECODE > ====
        DC_RD_ID                : out std_logic_vector(4 downto 0);
        DC_RD_DATA              : out std_logic_vector(31 downto 0);
        DC_RD_WE                : out std_logic
    );
end entity;

architecture rtl of lagarisc_stage_wb is
begin
    DC_RD_ID    <=  MEM_RD_ID;

    DC_RD_DATA  <=  MEM_ALU_RESULT when MEM_WB_MUX = MUX_WB_SRC_ALU else
                    MEM_MEM_DOUT when MEM_WB_MUX = MUX_WB_SRC_MEM else
                    MEM_PC_NOT_TAKEN;

    DC_RD_WE    <=  MEM_MEM_WE when MEM_WB_MUX = MUX_WB_SRC_MEM else MEM_RD_WE;
end architecture;