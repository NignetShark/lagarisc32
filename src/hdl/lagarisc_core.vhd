library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_core is
    generic (
        G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000";
        G_BRAM_LATENCY  : positive                      := 1
    );
    port (
        CLK                 : in std_logic;
        RST                 : in std_logic;

        -- ==== BRAM interface ====
        BRAM_EN             : out  std_logic;
        BRAM_ADDR           : out  std_logic_vector(31 downto 0);
        BRAM_DOUT           : in   std_logic_vector(31 downto 0)
    );
    end entity;

architecture rtl of lagarisc_core is

    signal fetch_ready              : std_logic;
    signal exec_ready               : std_logic;
    signal mem_ready                : std_logic;

    signal fetch_stall              : std_logic;
    signal decode_stall             : std_logic;
    signal exec_stall               : std_logic;
    signal mem_stall                : std_logic;

    signal fetch_flush              : std_logic;
    signal decode_flush             : std_logic;
    signal exec_flush               : std_logic;
    signal mem_flush                : std_logic;

    signal fetch_branch_taken       : std_logic;
    signal fetch_pc_taken           : std_logic_vector(31 downto 0);

    signal dc_exec_program_counter  : std_logic_vector(31 downto 0);
    signal dc_inst_data             : std_logic_vector(31 downto 0);
    signal dc_inst_valid            : std_logic;

    signal exec_program_counter     : std_logic_vector(31 downto 0);
    signal exec_branch_op           : branch_op_t;
    signal exec_branch_imm          : std_logic_vector(31 downto 0);
    signal exec_branch_src          : mux_branch_src_t;
    signal exec_inst_f3             : std_logic_vector(2 downto 0);
    signal exec_inst_f7             : std_logic_vector(6 downto 0);
    signal exec_inst_valid          : std_logic;
    signal exec_rs1_id              : std_logic_vector(4 downto 0);
    signal exec_rs2_id              : std_logic_vector(4 downto 0);
    signal exec_rs1_data            : std_logic_vector(31 downto 0);
    signal exec_rs2_data            : std_logic_vector(31 downto 0);
    signal exec_rd_id               : std_logic_vector(4 downto 0);
    signal exec_rd_we               : std_logic;
    signal exec_alu_opc             : alu_opcode_t;
    signal exec_alu_imm             : std_logic_vector(31 downto 0);
    signal exec_alu_shamt           : std_logic_vector(4 downto 0);
    signal exec_alu_op1_mux         : mux_alu_op1_t;
    signal exec_alu_op2_mux         : mux_alu_op2_t;
    signal exec_mem_en              : std_logic;
    signal exec_mem_we              : std_logic;
    signal exec_wb_mux              : mux_wb_src_t;

    signal mem_pc_taken             : std_logic_vector(31 downto 0);
    signal mem_pc_not_taken         : std_logic_vector(31 downto 0);
    signal mem_branch_op            : branch_op_t;
    signal mem_rd_id                : std_logic_vector(4 downto 0);
    signal mem_rd_we                : std_logic;
    signal mem_alu_result           : std_logic_vector(31 downto 0);
    signal mem_inst_f3              : std_logic_vector(2 downto 0);
    signal mem_inst_valid           : std_logic;
    signal mem_mem_din              : std_logic_vector(31 downto 0);
    signal mem_mem_en               : std_logic;
    signal mem_mem_we               : std_logic;
    signal mem_wb_mux               : mux_wb_src_t;

    signal wb_pc_not_taken          : std_logic_vector(31 downto 0);
    signal wb_rd_id                 : std_logic_vector(4 downto 0);
    signal wb_rd_we                 : std_logic;
    signal wb_alu_result            : std_logic_vector(31 downto 0);
    signal wb_mem_dout              : std_logic_vector(31 downto 0);
    signal wb_mem_valid             : std_logic;
    signal wb_wb_mux                : mux_wb_src_t;

    signal dc_rd_id                 : std_logic_vector(4 downto 0);
    signal dc_rd_data               : std_logic_vector(31 downto 0);
    signal dc_rd_we                 : std_logic;
begin

    inst_supervisor : lagarisc_supervisor
        port map (
            CLK                 => CLK,
            RST                 => RST,

            -- Ready
            FETCH_READY         => fetch_ready,
            EXEC_READY          => exec_ready,
            MEM_READY           => mem_ready,

            -- Validity
            EXEC_INST_VALID     => exec_inst_valid,
            MEM_INST_VALID      => mem_inst_valid,

            -- Branch taken ?
            MEM_BRANCH_TAKEN    => fetch_branch_taken,

            -- Flush
            FETCH_FLUSH         => fetch_flush,
            DECODE_FLUSH        => decode_flush,
            EXEC_FLUSH          => exec_flush,
            MEM_FLUSH           => mem_flush,

            -- Stall
            FETCH_STALL         => fetch_stall,
            DECODE_STALL        => decode_stall,
            EXEC_STALL          => exec_stall,
            MEM_STALL           => mem_stall
        );

    inst_fetch_bram : lagarisc_fetch_bram
        generic map (
            G_BOOT_ADDR     => G_BOOT_ADDR,
            G_BRAM_LATENCY  => G_BRAM_LATENCY
        )
        port map(
            CLK                     => CLK,
            RST                     => RST,

            -- ==== Control & command ====
            STAGE_READY             => fetch_ready,
            FLUSH                   => fetch_flush,
            STALL                   => fetch_stall,

            -- ==== BRAM interface ====
            BRAM_EN                 => BRAM_EN,
            BRAM_ADDR               => BRAM_ADDR,
            BRAM_DOUT               => BRAM_DOUT,

            -- ==== DECODE stage ====
            DC_EXEC_PROGRAM_COUNTER => dc_exec_program_counter,
            DC_INST_DATA            => dc_inst_data,
            DC_INST_VALID           => dc_inst_valid,

            -- === MEMORY stage ===
            MEM_BRANCH_TAKEN        => fetch_branch_taken,
            MEM_PC_TAKEN            => fetch_pc_taken
        );

    inst_stage_decode : lagarisc_stage_decode
        port map (
            CLK                         => CLK,
            RST                         => RST,

            -- ==== Control & command ====
            STALL                       => decode_stall,
            FLUSH                       => decode_flush,

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER       => dc_exec_program_counter,
            FETCH_INST_DATA             => dc_inst_data,
            FETCH_INST_VALID            => dc_inst_valid,

            -- ==== EXEC > ====
            -- PC
            EXEC_PROGRAM_COUNTER        => exec_program_counter,
            EXEC_BRANCH_OP              => exec_branch_op,
            EXEC_BRANCH_IMM             => exec_branch_imm,
            EXEC_BRANCH_SRC             => exec_branch_src,
            -- ALU
            EXEC_INST_F3                => exec_inst_f3,
            EXEC_INST_F7                => exec_inst_f7,
            EXEC_INST_VALID             => exec_inst_valid,
            -- RSX
            EXEC_RS1_DATA               => exec_rs1_data,
            EXEC_RS2_DATA               => exec_rs2_data,
            -- RD
            EXEC_RS1_ID                 => exec_rs1_id,
            EXEC_RS2_ID                 => exec_rs2_id,
            EXEC_RD_ID                  => exec_rd_id,
            EXEC_RD_WE                  => exec_rd_we,
            -- ALU
            EXEC_ALU_OPC                => exec_alu_opc,
            EXEC_ALU_IMM                => exec_alu_imm,
            EXEC_ALU_SHAMT              => exec_alu_shamt,
            EXEC_ALU_OP1_MUX            => exec_alu_op1_mux,
            EXEC_ALU_OP2_MUX            => exec_alu_op2_mux,
            -- MEM
            EXEC_MEM_EN                 => exec_mem_en,
            EXEC_MEM_WE                 => exec_mem_we,
            -- WB MUX
            EXEC_WB_MUX                 => exec_wb_mux,

            -- ==== > WRITE-BACK ====
            WB_RD_ID                    => dc_rd_id,
            WB_RD_DATA                  => dc_rd_data,
            WB_RD_WE                    => dc_rd_we
        );

    inst_stage_exec : lagarisc_stage_exec
        port map (
            CLK                 => CLK,
            RST                 => RST,

            STAGE_READY         => exec_ready,
            STALL               => exec_stall,
            FLUSH               => exec_flush,

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER   => dc_exec_program_counter,

            -- ==== > DECODE ====
            -- PC
            DC_PROGRAM_COUNTER      => exec_program_counter,
            DC_BRANCH_OP            => exec_branch_op,
            DC_BRANCH_IMM           => exec_branch_imm,
            DC_BRANCH_SRC           => exec_branch_src,
            -- INST
            DC_INST_F3              => exec_inst_f3,
            DC_INST_F7              => exec_inst_f7,
            DC_INST_VALID           => exec_inst_valid,
            -- RSX
            DC_RS1_ID               => exec_rs1_id,
            DC_RS2_ID               => exec_rs2_id,
            DC_RS1_DATA             => exec_rs1_data,
            DC_RS2_DATA             => exec_rs2_data,
            -- RD
            DC_RD_ID                => exec_rd_id,
            DC_RD_WE                => exec_rd_we,
            -- ALU
            DC_ALU_OPC              => exec_alu_opc,
            DC_ALU_IMM              => exec_alu_imm,
            DC_ALU_SHAMT            => exec_alu_shamt,
            DC_ALU_OP1_MUX          => exec_alu_op1_mux,
            DC_ALU_OP2_MUX          => exec_alu_op2_mux,
            -- MEM
            DC_MEM_EN               => exec_mem_en,
            DC_MEM_WE               => exec_mem_we,
            -- WB
            DC_WB_MUX               => exec_wb_mux,

            -- ==== MEM > ====
            -- PC
            MEM_PC_TAKEN            => mem_pc_taken,
            MEM_PC_NOT_TAKEN        => mem_pc_not_taken,
            MEM_BRANCH_OP           => mem_branch_op,
            -- INST
            MEM_INST_F3             => mem_inst_f3,
            MEM_INST_VALID          => mem_inst_valid,
            -- RD
            MEM_RD_ID               => mem_rd_id,
            MEM_RD_WE               => mem_rd_we,
            -- FWD RD
            MEM_FWD_RD_ID           => mem_rd_id,
            MEM_FWD_RD_DATA         => mem_alu_result,
            MEM_FWD_RD_WE           => mem_rd_we,
            -- ALU
            MEM_ALU_RESULT          => mem_alu_result,
            -- MEM
            MEM_MEM_DIN             => mem_mem_din,
            MEM_MEM_EN              => mem_mem_en,
            MEM_MEM_WE              => mem_mem_we,
            -- WB MUX
            MEM_WB_MUX              => mem_wb_mux,

            -- ==== > WB ====
            WB_FWD_RD_ID            => dc_rd_id,
            WB_FWD_RD_DATA          => dc_rd_data,
            WB_FWD_RD_WE            => dc_rd_we
        );

    inst_stage_mem : lagarisc_stage_mem
        generic map (
            G_BOOT_ADDR     => G_BOOT_ADDR
        )
        port map (
            CLK                     => CLK,
            RST                     => RST,

            STAGE_READY             => mem_ready,
            FLUSH                   => mem_flush,
            STALL                   => mem_stall,

            -- ==== > EXEC ====
            -- PC
            EXEC_PC_TAKEN           => mem_pc_taken,
            EXEC_PC_NOT_TAKEN       => mem_pc_not_taken,
            EXEC_BRANCH_OP          => mem_branch_op,
            -- INST
            EXEC_INST_F3            => mem_inst_f3,
            EXEC_INST_VALID         => mem_inst_valid,
            -- RD
            EXEC_RD_ID              => mem_rd_id,
            EXEC_RD_WE              => mem_rd_we,
            -- ALU
            EXEC_ALU_RESULT         => mem_alu_result,
            -- MEM
            EXEC_MEM_DIN            => mem_mem_din,
            EXEC_MEM_EN             => mem_mem_en,
            EXEC_MEM_WE             => mem_mem_we,
            -- WB MUX
            EXEC_WB_MUX             => mem_wb_mux,

            -- ==== FETCH > ====
            -- PC
            FETCH_BRANCH_TAKEN      => fetch_branch_taken,
            FETCH_PC_TAKEN          => fetch_pc_taken,

            -- ==== WB > ====
            -- PC
            WB_PC_NOT_TAKEN         => wb_pc_not_taken,
            -- RD
            WB_RD_ID                => wb_rd_id,
            WB_RD_WE                => wb_rd_we,
            -- ALU
            WB_ALU_RESULT           => wb_alu_result,
            -- MEM
            WB_MEM_DOUT             => wb_mem_dout,
            WB_MEM_VALID            => wb_mem_valid,
            -- WB MUX
            WB_WB_MUX               => wb_wb_mux
        );

    inst_stage_wb : lagarisc_stage_wb
        port map (
            CLK                 => CLK,
            RST                 => RST,

            STAGE_READY         => open,

            -- ==== > MEM ====
            -- PC
            MEM_PC_NOT_TAKEN    => wb_pc_not_taken,
            -- RD
            MEM_RD_ID           => wb_rd_id,
            MEM_RD_WE           => wb_rd_we,
            -- ALU
            MEM_ALU_RESULT      => wb_alu_result,
            -- MEM
            MEM_MEM_DOUT        => wb_mem_dout,
            MEM_MEM_VALID       => wb_mem_valid,
            -- WB
            MEM_WB_MUX          => wb_wb_mux,

            -- ==== DECODE > ====
            DC_RD_ID            => dc_rd_id,
            DC_RD_DATA          => dc_rd_data,
            DC_RD_WE            => dc_rd_we
        );


end architecture;