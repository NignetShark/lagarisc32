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
        -- CSR
        MEM_CSR_ID              : in std_logic_vector(11 downto 0);
        MEM_CSR_OPCODE          : in csr_opcode_t;
        -- WB
        MEM_WB_MUX              : in mux_wb_src_t;

        -- ==== DECODE > ====
        DC_RD_ID                : out std_logic_vector(4 downto 0);
        DC_RD_DATA              : out std_logic_vector(31 downto 0);
        DC_RD_WE                : out std_logic
    );
end entity;

architecture rtl of lagarisc_stage_wb is
    signal dc_csr_dout : std_logic_vector(31 downto 0);
    signal dc_csr_we   : std_logic;
begin
    DC_RD_ID    <=  MEM_RD_ID;

    DC_RD_DATA  <=  MEM_ALU_RESULT      when MEM_WB_MUX = MUX_WB_SRC_ALU else
                    MEM_MEM_DOUT        when MEM_WB_MUX = MUX_WB_SRC_MEM else
                    MEM_PC_NOT_TAKEN    when MEM_WB_MUX = MUX_WB_SRC_PC else
                    dc_csr_dout;

    DC_RD_WE    <=  MEM_MEM_WE  when MEM_WB_MUX = MUX_WB_SRC_MEM else
                    dc_csr_we   when MEM_WB_MUX = MUX_WB_SRC_CSR
                    else MEM_RD_WE;

    -----------------------------------------
    -- CSR registers
    -----------------------------------------
    inst_csr : lagarisc_csr
        port map(
            CLK                 => CLK,
            RST                 => RST,

            -- ==== > WB ====
            MEM_CSR_ID           => MEM_CSR_ID,
            -- INST
            MEM_CSR_OPCODE       => MEM_CSR_OPCODE,
            -- RS1 (or immediat)
            MEM_RS1_DATA         => MEM_ALU_RESULT,

            -- ==== REGFILE > ====
            DC_CSR_WE            => dc_csr_we,  -- Output combinatorial
            DC_CSR_DOUT          => dc_csr_dout -- Output combinatorial
        );
end architecture;