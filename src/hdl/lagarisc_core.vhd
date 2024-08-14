library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_core is
    generic (
        G_BOOT_ADDR                 : std_logic_vector(31 downto 0) := x"80000000";
        G_INST_NB_ISSUES            : positive  := 3
    );
    port (
        CLK                         : in std_logic;
        RST                         : in std_logic;

        -- ==== > Instruction BRAM interface > ====
        INST_AXI_ARVALID            : out std_logic;
        INST_AXI_ARREADY            : in  std_logic;
        INST_AXI_ARADDR             : out std_logic_vector(31 downto 0);
        INST_AXI_ARPROT             : out std_logic_vector(2 downto 0);
        INST_AXI_RVALID             : in  std_logic;
        INST_AXI_RREADY             : out std_logic;
        INST_AXI_RDATA              : in  std_logic_vector(31 downto 0);
        INST_AXI_RESP               : in  std_logic_vector(1 downto 0);

        -- ==== > Data AXI4L interface > ====
        -- write access
        DATA_AXI_AWVALID            : out std_logic;
        DATA_AXI_AWREADY            : in  std_logic;
        DATA_AXI_AWADDR             : out std_logic_vector(31 downto 0);
        DATA_AXI_AWPROT             : out std_logic_vector(2 downto 0);
        DATA_AXI_WVALID             : out std_logic;
        DATA_AXI_WREADY             : in  std_logic;
        DATA_AXI_WDATA              : out std_logic_vector(31 downto 0);
        DATA_AXI_WSTRB              : out std_logic_vector(3 downto 0);
        DATA_AXI_BVALID             : in  std_logic;
        DATA_AXI_BREADY             : out std_logic;
        DATA_AXI_BRESP              : in  std_logic_vector(1 downto 0);
        -- read access
        DATA_AXI_ARVALID            : out std_logic;
        DATA_AXI_ARREADY            : in  std_logic;
        DATA_AXI_ARADDR             : out std_logic_vector(31 downto 0);
        DATA_AXI_ARPROT             : out std_logic_vector(2 downto 0);
        DATA_AXI_RVALID             : in  std_logic;
        DATA_AXI_RREADY             : out std_logic;
        DATA_AXI_RDATA              : in  std_logic_vector(31 downto 0);
        DATA_AXI_RESP               : in  std_logic_vector(1 downto 0)
    );
    end entity;

architecture rtl of lagarisc_core is

    signal decode_flush             : std_logic;
    signal exec_flush               : std_logic;
    signal mem_stall                : std_logic;
    signal mem_flush                : std_logic;
    signal mem_flush_ack            : std_logic;

    signal fetch_branch_ready       : std_logic;
    signal fetch_out_valid          : std_logic;
    signal decode_in_ready          : std_logic;
    signal decode_out_valid         : std_logic;
    signal exec_in_ready            : std_logic;
    signal exec_out_valid           : std_logic;
    signal mem_in_ready             : std_logic;

    signal fetch_branch_taken       : std_logic;
    signal fetch_pc_taken           : std_logic_vector(31 downto 0);

    signal dc_exec_program_counter  : std_logic_vector(31 downto 0);
    signal dc_inst_data             : std_logic_vector(31 downto 0);

    signal exec_program_counter     : std_logic_vector(31 downto 0);
    signal exec_branch_op           : branch_op_t;
    signal exec_branch_imm          : std_logic_vector(31 downto 0);
    signal exec_branch_src          : mux_branch_src_t;
    signal exec_inst_f3             : std_logic_vector(2 downto 0);
    signal exec_inst_f7             : std_logic_vector(6 downto 0);
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
    signal exec_csr_id              : std_logic_vector(11 downto 0);
    signal exec_csr_opcode          : csr_opcode_t;
    signal exec_wb_mux              : mux_wb_src_t;

    signal mem_pc_taken             : std_logic_vector(31 downto 0);
    signal mem_pc_not_taken         : std_logic_vector(31 downto 0);
    signal mem_branch_op            : branch_op_t;
    signal mem_inst_f3              : std_logic_vector(2 downto 0);
    signal mem_rd_id                : std_logic_vector(4 downto 0);
    signal mem_rd_we                : std_logic;
    signal mem_alu_result           : std_logic_vector(31 downto 0);
    signal mem_mem_din              : std_logic_vector(31 downto 0);
    signal mem_mem_en               : std_logic;
    signal mem_mem_we               : std_logic;
    signal mem_csr_id               : std_logic_vector(11 downto 0);
    signal mem_csr_opcode           : csr_opcode_t;
    signal mem_wb_mux               : mux_wb_src_t;

    signal wb_pc_not_taken          : std_logic_vector(31 downto 0);
    signal wb_rd_id                 : std_logic_vector(4 downto 0);
    signal wb_rd_we                 : std_logic;
    signal wb_alu_result            : std_logic_vector(31 downto 0);
    signal wb_mem_dout              : std_logic_vector(31 downto 0);
    signal wb_mem_we                : std_logic;
    signal wb_csr_id                : std_logic_vector(11 downto 0);
    signal wb_csr_opcode            : csr_opcode_t;
    signal wb_wb_mux                : mux_wb_src_t;

    signal dc_rd_id                 : std_logic_vector(4 downto 0);
    signal dc_rd_data               : std_logic_vector(31 downto 0);
    signal dc_rd_we                 : std_logic;

    signal sup_branch_taken         : std_logic;
    signal sup_pc_taken             : std_logic_vector(31 downto 0);
begin

    inst_supervisor : lagarisc_supervisor
        generic map (
            G_BOOT_ADDR     => G_BOOT_ADDR
        )
        port map (
            CLK                 => CLK,
            RST                 => RST,

            -- ==== > MEM ====
            MEM_FLUSH_ACK       => mem_flush_ack,     -- Memory must ack flush before desasserting flush signal (defered flush)
            MEM_BRANCH_TAKEN    => sup_branch_taken,
            MEM_PC_TAKEN        => sup_pc_taken,

            -- ==== > FETCH ====
            FETCH_BRANCH_TAKEN  => fetch_branch_taken,
            FETCH_PC_TAKEN      => fetch_pc_taken,
            FETCH_BRANCH_READY  => fetch_branch_ready,

            -- ==== Flush ====
            DECODE_FLUSH        => decode_flush,
            EXEC_FLUSH          => exec_flush,
            MEM_FLUSH           => mem_flush,

            -- ==== Stall ====
            MEM_STALL           => mem_stall
        );

    inst_fetch_axi4l : lagarisc_fetch_axi4l
        generic map (
            G_NB_ISSUES                 => G_INST_NB_ISSUES
        )
        port map (
            CLK                         => CLK,
            RST                         => RST,

            -- ==== Control & command ====
            FETCH_OUT_VALID             => fetch_out_valid,
            DECODE_IN_READY             => decode_in_ready,
            FETCH_BRANCH_READY          => fetch_branch_ready,

            -- ==== DECODE & EXEC stage > ====
            DC_EXEC_PROGRAM_COUNTER     => dc_exec_program_counter,

            -- ==== DECODE > ====
            DC_INST_DATA                => dc_inst_data,

            -- === > SUPERVISOR ===
            SUP_BRANCH_TAKEN            => fetch_branch_taken,
            SUP_PC_TAKEN                => fetch_pc_taken,

            -- ==== AXI4L read interface ====
            AXI_ARVALID                 => INST_AXI_ARVALID,
            AXI_ARREADY                 => INST_AXI_ARREADY,
            AXI_ARADDR                  => INST_AXI_ARADDR,
            AXI_ARPROT                  => INST_AXI_ARPROT,
            AXI_RVALID                  => INST_AXI_RVALID,
            AXI_RREADY                  => INST_AXI_RREADY,
            AXI_RDATA                   => INST_AXI_RDATA,
            AXI_RESP                    => INST_AXI_RESP
        );

    inst_stage_decode : lagarisc_stage_decode
        port map (
            CLK                         => CLK,
            RST                         => RST,

            -- ==== Control & command ====
            FLUSH                       => decode_flush,

            -- Valid & ready
            FETCH_OUT_VALID             => fetch_out_valid,
            DECODE_IN_READY             => decode_in_ready,
            DECODE_OUT_VALID            => decode_out_valid,
            EXEC_IN_READY               => exec_in_ready,

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER       => dc_exec_program_counter,
            FETCH_INST_DATA             => dc_inst_data,

            -- ==== EXEC > ====
            -- PC
            EXEC_PROGRAM_COUNTER        => exec_program_counter,
            EXEC_BRANCH_OP              => exec_branch_op,
            EXEC_BRANCH_IMM             => exec_branch_imm,
            EXEC_BRANCH_SRC             => exec_branch_src,
            -- ALU
            EXEC_INST_F3                => exec_inst_f3,
            EXEC_INST_F7                => exec_inst_f7,
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
            -- CSR
            EXEC_CSR_ID                 => exec_csr_id,
            EXEC_CSR_OPCODE             => exec_csr_opcode,
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

            -- ==== Control & command ====
            FLUSH               => exec_flush,

            DECODE_OUT_VALID    => decode_out_valid,
            EXEC_IN_READY       => exec_in_ready,
            EXEC_OUT_VALID      => exec_out_valid,
            MEM_IN_READY        => mem_in_ready,

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
            -- CSR
            DC_CSR_ID               => exec_csr_id,
            DC_CSR_OPCODE           => exec_csr_opcode,
            -- WB
            DC_WB_MUX               => exec_wb_mux,

            -- ==== MEM > ====
            -- PC
            MEM_PC_TAKEN            => mem_pc_taken,
            MEM_PC_NOT_TAKEN        => mem_pc_not_taken,
            MEM_BRANCH_OP           => mem_branch_op,
            -- INST
            MEM_INST_F3             => mem_inst_f3,
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
            -- CSR
            MEM_CSR_ID              => mem_csr_id,
            MEM_CSR_OPCODE          => mem_csr_opcode,
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

            -- ==== Control & command ====
            STALL                   => mem_stall,
            FLUSH                   => mem_flush,
            FLUSH_ACK               => mem_flush_ack,

            EXEC_OUT_VALID          => exec_out_valid,
            MEM_IN_READY            => mem_in_ready,

            -- ==== > EXEC ====
            -- PC
            EXEC_PC_TAKEN           => mem_pc_taken,
            EXEC_PC_NOT_TAKEN       => mem_pc_not_taken,
            EXEC_BRANCH_OP          => mem_branch_op,
            -- INST
            EXEC_INST_F3            => mem_inst_f3,
            -- RD
            EXEC_RD_ID              => mem_rd_id,
            EXEC_RD_WE              => mem_rd_we,
            -- ALU
            EXEC_ALU_RESULT         => mem_alu_result,
            -- MEM
            EXEC_MEM_DIN            => mem_mem_din,
            EXEC_MEM_EN             => mem_mem_en,
            EXEC_MEM_WE             => mem_mem_we,
            -- CSR
            EXEC_CSR_ID             => mem_csr_id,
            EXEC_CSR_OPCODE         => mem_csr_opcode,
            -- WB MUX
            EXEC_WB_MUX             => mem_wb_mux,

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
            WB_MEM_WE               => wb_mem_we,
            -- CSR
            WB_CSR_ID               => wb_csr_id,
            WB_CSR_OPCODE           => wb_csr_opcode,
            -- WB MUX
            WB_WB_MUX               => wb_wb_mux,

            -- ==== SUP > ====
            -- PC
            SUP_BRANCH_TAKEN      => sup_branch_taken,
            SUP_PC_TAKEN          => sup_pc_taken,

            -- ==== > AXI4L interface > ====
            -- write access
            AXI_AWVALID             => DATA_AXI_AWVALID,
            AXI_AWREADY             => DATA_AXI_AWREADY,
            AXI_AWADDR              => DATA_AXI_AWADDR,
            AXI_AWPROT              => DATA_AXI_AWPROT,
            AXI_WVALID              => DATA_AXI_WVALID,
            AXI_WREADY              => DATA_AXI_WREADY,
            AXI_WDATA               => DATA_AXI_WDATA,
            AXI_WSTRB               => DATA_AXI_WSTRB,
            AXI_BVALID              => DATA_AXI_BVALID,
            AXI_BREADY              => DATA_AXI_BREADY,
            AXI_BRESP               => DATA_AXI_BRESP,
            --read access
            AXI_ARVALID             => DATA_AXI_ARVALID,
            AXI_ARREADY             => DATA_AXI_ARREADY,
            AXI_ARADDR              => DATA_AXI_ARADDR,
            AXI_ARPROT              => DATA_AXI_ARPROT,
            AXI_RVALID              => DATA_AXI_RVALID,
            AXI_RREADY              => DATA_AXI_RREADY,
            AXI_RDATA               => DATA_AXI_RDATA,
            AXI_RESP                => DATA_AXI_RESP
        );

    inst_stage_wb : lagarisc_stage_wb
        port map (
            CLK                 => CLK,
            RST                 => RST,

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
            MEM_MEM_WE          => wb_mem_we,
            -- CSR
            MEM_CSR_ID          => wb_csr_id,
            MEM_CSR_OPCODE      => wb_csr_opcode,
            -- WB
            MEM_WB_MUX          => wb_wb_mux,

            -- ==== DECODE > ====
            DC_RD_ID            => dc_rd_id,
            DC_RD_DATA          => dc_rd_data,
            DC_RD_WE            => dc_rd_we
        );


end architecture;