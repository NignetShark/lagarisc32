library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_decode is
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        -- ==== Control & command ====
        FLUSH                   : in std_logic;

        -- Valid & ready
        FETCH_OUT_VALID         : in std_logic;
        DECODE_IN_READY         : out std_logic;
        DECODE_OUT_VALID        : out std_logic;
        EXEC_IN_READY           : in std_logic;

        -- ==== > FETCH ====
        FETCH_PROGRAM_COUNTER   : in  std_logic_vector(31 downto 0);
        FETCH_INST_DATA         : in  std_logic_vector(31 downto 0);

        -- ==== EXEC > ====
        -- PC
        EXEC_PROGRAM_COUNTER    : out std_logic_vector(31 downto 0);
        EXEC_BRANCH_OP          : out branch_op_t;
        EXEC_BRANCH_IMM         : out std_logic_vector(31 downto 0);
        EXEC_BRANCH_SRC         : out mux_branch_src_t;
        -- INST FX
        EXEC_INST_F3            : out std_logic_vector(2 downto 0);
        -- RSX
        EXEC_RS1_ID             : out std_logic_vector(4 downto 0);
        EXEC_RS2_ID             : out std_logic_vector(4 downto 0);
        EXEC_RS1_DATA           : out std_logic_vector(31 downto 0);
        EXEC_RS2_DATA           : out std_logic_vector(31 downto 0);
        -- RD
        EXEC_RD_ID              : out std_logic_vector(4 downto 0);
        EXEC_RD_WE              : out std_logic;
        -- ALU
        EXEC_ALU_OPC            : out alu_opcode_t;
        EXEC_ALU_IMM            : out std_logic_vector(31 downto 0);
        EXEC_ALU_SHAMT          : out std_logic_vector(4 downto 0);
        EXEC_ALU_OP1_MUX        : out mux_alu_op1_t;
        EXEC_ALU_OP2_MUX        : out mux_alu_op2_t;
        -- LSU
        EXEC_LSU_EN             : out std_logic;
        EXEC_LSU_WE             : out std_logic;
        -- CSR
        EXEC_CSR_ID             : out std_logic_vector(11 downto 0);
        EXEC_CSR_OPCODE         : out csr_opcode_t;
        -- WB MUX
        EXEC_WB_MUX             : out mux_wb_src_t;

        -- ==== > WRITE-BACK ====
        WB_RD_ID                : in std_logic_vector(4 downto 0);
        WB_RD_DATA              : in std_logic_vector(31 downto 0);
        WB_RD_WE                : in std_logic;
        WB_RD_VALID             : in std_logic
    );
end entity;

architecture rtl of lagarisc_stage_decode is
    signal regfile_rs1_id          : std_logic_vector(4 downto 0);
    signal regfile_rs2_id          : std_logic_vector(4 downto 0);
begin

    inst_decode : lagarisc_decode
        port map (
            CLK                     => CLK,
            RST                     => RST,

            -- ==== Control & command ====
            FLUSH                   => FLUSH,

            -- Valid & ready
            FETCH_OUT_VALID         => FETCH_OUT_VALID,
            DECODE_IN_READY         => DECODE_IN_READY,
            DECODE_OUT_VALID        => DECODE_OUT_VALID,
            EXEC_IN_READY           => EXEC_IN_READY,

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER   => FETCH_PROGRAM_COUNTER,
            FETCH_INST_DATA         => FETCH_INST_DATA,

            -- ==== REG FILE > ====
            REGFILE_RS1_ID          => regfile_rs1_id,
            REGFILE_RS2_ID          => regfile_rs2_id,

            -- ==== EXEC > ====
            -- PC
            EXEC_PROGRAM_COUNTER    => EXEC_PROGRAM_COUNTER,
            EXEC_BRANCH_OP          => EXEC_BRANCH_OP,
            EXEC_BRANCH_IMM         => EXEC_BRANCH_IMM,
            EXEC_BRANCH_SRC         => EXEC_BRANCH_SRC,
            -- INST FX
            EXEC_INST_F3            => EXEC_INST_F3,
            -- RSX
            EXEC_RS1_ID             => EXEC_RS1_ID,
            EXEC_RS2_ID             => EXEC_RS2_ID,
            -- RD
            EXEC_RD_ID              => EXEC_RD_ID,
            EXEC_RD_WE              => EXEC_RD_WE,
            -- ALU
            EXEC_ALU_OPC            => EXEC_ALU_OPC,
            EXEC_ALU_IMM            => EXEC_ALU_IMM,
            EXEC_ALU_SHAMT          => EXEC_ALU_SHAMT,
            EXEC_ALU_OP1_MUX        => EXEC_ALU_OP1_MUX,
            EXEC_ALU_OP2_MUX        => EXEC_ALU_OP2_MUX,
            -- LSU
            EXEC_LSU_EN             => EXEC_LSU_EN,
            EXEC_LSU_WE             => EXEC_LSU_WE,
            -- CSR
            EXEC_CSR_ID             => EXEC_CSR_ID,
            EXEC_CSR_OPCODE         => EXEC_CSR_OPCODE,
            -- WB MUX
            EXEC_WB_MUX             => EXEC_WB_MUX
        );

    inst_regfile : lagarisc_regfile
        port map (
            CLK             => CLK,
            RST             => RST,

            -- From decode stage
            DC_RS1_ID       => regfile_rs1_id,
            DC_RS2_ID       => regfile_rs2_id,

            -- Register file output
            RS1_DATA        => EXEC_RS1_DATA,
            RS2_DATA        => EXEC_RS2_DATA,

            -- From memory stage
            WB_RD_ID        => WB_RD_ID,
            WB_RD_DATA      => WB_RD_DATA,
            WB_RD_WE        => WB_RD_WE,
            WB_RD_VALID     => WB_RD_VALID
        );

end architecture;
