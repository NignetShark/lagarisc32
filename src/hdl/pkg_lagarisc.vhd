library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package pkg_lagarisc is

    constant C_NATIVE_SIZE : integer := 32;

    type branch_op_t is (BRANCH_NOP, BRANCH_OP_COND, BRANCH_OP_UNCOND);
    type mux_branch_src_t is (MUX_BRANCH_SRC_PC, MUX_BRANCH_SRC_RS1); -- PC += IMM or PC = RS1 + IMM

    type mux_alu_op1_t is (MUX_ALU_OP1_RS1, MUX_ALU_OP1_PC);
    type mux_alu_op2_t is (MUX_ALU_OP2_RS2, MUX_ALU_OP2_IMM);
    type mux_wb_src_t  is (MUX_WB_SRC_MEM, MUX_WB_SRC_ALU, MUX_WB_SRC_PC);


    -----------------------------------------------------
    -- RV32I OPCODES
    -----------------------------------------------------
    constant C_OP_LUI       : std_logic_vector(6 downto 0) := "0110111";
    constant C_OP_AUIPC     : std_logic_vector(6 downto 0) := "0010111";
    constant C_OP_JAL       : std_logic_vector(6 downto 0) := "1101111";
    constant C_OP_JALR      : std_logic_vector(6 downto 0) := "1100111";
    constant C_OP_BRANCH    : std_logic_vector(6 downto 0) := "1100011";
    constant C_OP_LOAD      : std_logic_vector(6 downto 0) := "0000011";
    constant C_OP_STORE     : std_logic_vector(6 downto 0) := "0100011";
    constant C_OP_ARTHI     : std_logic_vector(6 downto 0) := "0010011";
    constant C_OP_ARTH      : std_logic_vector(6 downto 0) := "0110011";
    constant C_OP_EXT       : std_logic_vector(6 downto 0) := "1110011";
    constant C_OP_FENCE     : std_logic_vector(6 downto 0) := "0001111";

    -----------------------------------------------------
    -- F3
    -----------------------------------------------------
    -- ALU
    constant C_F3_ADD_SUB   : std_logic_vector(2 downto 0):="000";
    constant C_F3_SLT       : std_logic_vector(2 downto 0):="010";
    constant C_F3_SLTU      : std_logic_vector(2 downto 0):="011";
    constant C_F3_XOR       : std_logic_vector(2 downto 0):="100";
    constant C_F3_OR        : std_logic_vector(2 downto 0):="110";
    constant C_F3_AND       : std_logic_vector(2 downto 0):="111";
    constant C_F3_SLL       : std_logic_vector(2 downto 0):="001";
    constant C_F3_SRL_SRA   : std_logic_vector(2 downto 0):="101";

    -- BRANCH
    constant C_F3_BEQ       : std_logic_vector(2 downto 0):="000";
    constant C_F3_BNE       : std_logic_vector(2 downto 0):="001";
    constant C_F3_BLT       : std_logic_vector(2 downto 0):="100";
    constant C_F3_BGE       : std_logic_vector(2 downto 0):="101";
    constant C_F3_BLTU      : std_logic_vector(2 downto 0):="110";
    constant C_F3_BGEU      : std_logic_vector(2 downto 0):="111";

    -----------------------------------------------------
    -- F7
    -----------------------------------------------------
    constant C_F7_ADD       : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_SUB       : std_logic_vector(6 downto 0):="0100000";
    constant C_F7_SLL       : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_SLT       : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_SLTU      : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_XOR       : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_SRL       : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_SRA       : std_logic_vector(6 downto 0):="0100000";
    constant C_F7_OR        : std_logic_vector(6 downto 0):="0000000";
    constant C_F7_AND       : std_logic_vector(6 downto 0):="0000000";

    type alu_opcode_t is (
        ALU_OPCODE_ADD,     -- rd = op1 + op2
        ALU_OPCODE_SUB,     -- rd = op1 - op2
        ALU_OPCODE_SLL,     -- rd = op1 << op2
        ALU_OPCODE_SLT,     -- rd = (op1 < op2) ? 1:0
        ALU_OPCODE_SLTU,    -- rd = (op1 < op2) ? 1:0 [unsigned]
        ALU_OPCODE_XOR,     -- rd = op1 ? op2
        ALU_OPCODE_OR,      -- rd = op1 | op2
        ALU_OPCODE_AND,     -- rd = op1 & op2
        ALU_OPCODE_SRL,     -- rd = op1 >> op2
        ALU_OPCODE_SRA,     -- rd = op1 >> op2 (msb extended)
        -- Extended operations
        ALU_OPCODE_ZERO,    -- rd = 0
        ALU_OPCODE_SEQ,     -- rd = (op1 == op2) ? 1:0
        ALU_OPCODE_SNE,     -- rd = (op1 != op2) ? 1:0
        ALU_OPCODE_SGE,     -- rd = (op1 > op2) ? 1:0
        ALU_OPCODE_SGEU     -- rd = (op1 > op2) ? 1:0 [unsigned]
    );

    -----------------------------------------------------
    -- SUPERVISOR
    -----------------------------------------------------
    component lagarisc_supervisor is
        port (
            CLK   : in std_logic;
            RST   : in std_logic;

            -- Ready
            FETCH_READY         : in std_logic;
            EXEC_READY          : in std_logic;
            MEM_READY           : in std_logic;

            -- Validity
            EXEC_INST_VALID     : in std_logic;
            MEM_INST_VALID      : in std_logic;

            -- Branch taken ?
            MEM_BRANCH_TAKEN    : in std_logic;

            -- Flush
            FETCH_FLUSH         : out std_logic;
            DECODE_FLUSH        : out std_logic;
            EXEC_FLUSH          : out std_logic;
            MEM_FLUSH           : out std_logic;

            -- Stall
            FETCH_STALL         : out std_logic;
            DECODE_STALL        : out std_logic;
            EXEC_STALL          : out std_logic;
            MEM_STALL           : out std_logic
        );
    end component;

    -----------------------------------------------------
    -- STAGES
    -----------------------------------------------------
    component lagarisc_fetch_bram is
        generic (
            G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000";
            G_BRAM_LATENCY  : positive                      := 1
        );
        port (
            CLK                         : in std_logic;
            RST                         : in std_logic;

            -- ==== Control & command ====
            STAGE_READY                 : out std_logic;
            FLUSH                       : in  std_logic;
            STALL                       : in  std_logic;

            -- ==== BRAM interface ====
            BRAM_EN                     : out  std_logic;
            BRAM_ADDR                   : out  std_logic_vector(31 downto 0);
            BRAM_DOUT                   : in   std_logic_vector(31 downto 0);

            -- ==== DECODE & EXEC stage > ====
            DC_EXEC_PROGRAM_COUNTER     : out  std_logic_vector(31 downto 0);

            -- ==== DECODE > ====
            DC_INST_DATA                : out  std_logic_vector(31 downto 0);
            DC_INST_VALID               : out  std_logic;

            -- === > MEMORY stage ===
            MEM_BRANCH_TAKEN            : in std_logic;
            MEM_PC_TAKEN                : in std_logic_vector(31 downto 0)
        );
    end component;

    component lagarisc_stage_decode is
        port (
            CLK                     : in std_logic;
            RST                     : in std_logic;

            FLUSH                   : in std_logic;
            STALL                   : in std_logic;

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER   : in  std_logic_vector(31 downto 0);
            FETCH_INST_DATA         : in  std_logic_vector(31 downto 0);
            FETCH_INST_VALID        : in  std_logic;

            -- ==== EXEC > ====
            -- PC
            EXEC_PROGRAM_COUNTER    : out std_logic_vector(31 downto 0);
            EXEC_BRANCH_OP          : out branch_op_t;
            EXEC_BRANCH_IMM         : out std_logic_vector(31 downto 0);
            EXEC_BRANCH_SRC         : out mux_branch_src_t;
            -- INST FX
            EXEC_INST_F3            : out std_logic_vector(2 downto 0);
            EXEC_INST_F7            : out std_logic_vector(6 downto 0);
            EXEC_INST_VALID         : out std_logic;
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
            -- MEM
            EXEC_MEM_EN             : out std_logic;
            EXEC_MEM_WE             : out std_logic;
            -- WB MUX
            EXEC_WB_MUX             : out mux_wb_src_t;

            -- ==== > WRITE-BACK ====
            WB_RD_ID                : in std_logic_vector(4 downto 0);
            WB_RD_DATA              : in std_logic_vector(31 downto 0);
            WB_RD_WE                : in std_logic
        );
    end component;

    component lagarisc_stage_exec is
        port (
            CLK                     : in std_logic;
            RST                     : in std_logic;

            STAGE_READY             : out std_logic;
            FLUSH                   : in std_logic;
            STALL                   : in std_logic;

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER   : in std_logic_vector(31 downto 0);

            -- ==== > DECODE ====
            -- PC
            DC_PROGRAM_COUNTER      : in std_logic_vector(31 downto 0);
            DC_BRANCH_OP            : in branch_op_t;
            DC_BRANCH_IMM           : in std_logic_vector(31 downto 0);
            DC_BRANCH_SRC           : in mux_branch_src_t;
            -- INST
            DC_INST_F3              : in std_logic_vector(2 downto 0);
            DC_INST_F7              : in std_logic_vector(6 downto 0);
            DC_INST_VALID           : in std_logic;
            -- RSX
            DC_RS1_ID               : in std_logic_vector(4 downto 0);
            DC_RS2_ID               : in std_logic_vector(4 downto 0);
            DC_RS1_DATA             : in std_logic_vector(31 downto 0);
            DC_RS2_DATA             : in std_logic_vector(31 downto 0);
            -- RD
            DC_RD_ID                : in std_logic_vector(4 downto 0);
            DC_RD_WE                : in std_logic;
            -- ALU
            DC_ALU_OPC              : in alu_opcode_t;
            DC_ALU_IMM              : in std_logic_vector(31 downto 0);
            DC_ALU_SHAMT            : in std_logic_vector(4 downto 0);
            DC_ALU_OP1_MUX          : in mux_alu_op1_t;
            DC_ALU_OP2_MUX          : in mux_alu_op2_t;
            -- MEM
            DC_MEM_EN               : in std_logic;
            DC_MEM_WE               : in std_logic;
            -- WB MUX
            DC_WB_MUX               : in mux_wb_src_t;

            -- ==== MEM > ====
            -- PC
            MEM_PC_TAKEN            : out std_logic_vector(31 downto 0);
            MEM_PC_NOT_TAKEN        : out std_logic_vector(31 downto 0); -- PC + 4
            MEM_BRANCH_OP           : out branch_op_t;
            -- INST
            MEM_INST_F3             : out std_logic_vector(2 downto 0);
            MEM_INST_VALID          : out std_logic;
            -- RD
            MEM_RD_ID               : out std_logic_vector(4 downto 0);
            MEM_RD_WE               : out std_logic;
            -- FWD RD
            MEM_FWD_RD_ID           : in std_logic_vector(4 downto 0);
            MEM_FWD_RD_DATA         : in std_logic_vector(31 downto 0);
            MEM_FWD_RD_WE           : in std_logic;
            -- ALU
            MEM_ALU_RESULT          : out std_logic_vector(31 downto 0);
            -- MEM
            MEM_MEM_DIN             : out std_logic_vector(31 downto 0);
            MEM_MEM_EN              : out std_logic;
            MEM_MEM_WE              : out std_logic;
            -- WB MUX
            MEM_WB_MUX              : out mux_wb_src_t;

            -- ==== > WB ====
            WB_FWD_RD_ID            : in std_logic_vector(4 downto 0);
            WB_FWD_RD_DATA          : in std_logic_vector(31 downto 0);
            WB_FWD_RD_WE            : in std_logic
        );
    end component;

    component lagarisc_stage_mem is
        generic (
            G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000"
        );
        port (
            CLK                     : in std_logic;
            RST                     : in std_logic;

            STAGE_READY             : out std_logic;
            FLUSH                   : in std_logic;
            STALL                   : in std_logic;

            -- ==== > EXEC ====
            -- PC
            EXEC_PC_TAKEN           : in std_logic_vector(31 downto 0);
            EXEC_PC_NOT_TAKEN       : in std_logic_vector(31 downto 0); -- PC + 4
            EXEC_BRANCH_OP             : in branch_op_t;
            -- INST
            EXEC_INST_F3            : in std_logic_vector(2 downto 0);
            EXEC_INST_VALID         : in std_logic;
            -- RD
            EXEC_RD_ID              : in std_logic_vector(4 downto 0);
            EXEC_RD_WE              : in std_logic;
            -- ALU
            EXEC_ALU_RESULT         : in std_logic_vector(31 downto 0);
            -- MEM
            EXEC_MEM_DIN            : in std_logic_vector(31 downto 0);
            EXEC_MEM_EN             : in std_logic;
            EXEC_MEM_WE             : in std_logic;
            -- WB MUX
            EXEC_WB_MUX             : in mux_wb_src_t;

            -- ==== FETCH > ====
            -- PC
            FETCH_BRANCH_TAKEN      : out std_logic;
            FETCH_PC_TAKEN          : out std_logic_vector(31 downto 0);

            -- ==== WB > ====
            -- PC
            WB_PC_NOT_TAKEN         : out std_logic_vector(31 downto 0);
            -- RD
            WB_RD_ID                : out std_logic_vector(4 downto 0);
            WB_RD_WE                : out std_logic;
            -- ALU
            WB_ALU_RESULT           : out std_logic_vector(31 downto 0);
            -- MEM
            WB_MEM_DOUT             : out std_logic_vector(31 downto 0);
            WB_MEM_VALID            : out std_logic;
            -- WB MUX
            WB_WB_MUX               : out mux_wb_src_t
        );
    end component;

    component lagarisc_stage_wb is
        port (
            CLK                     : in std_logic;
            RST                     : in std_logic;

            STAGE_READY             : out std_logic;

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
            MEM_MEM_VALID           : in std_logic;
            -- WB
            MEM_WB_MUX              : in mux_wb_src_t;

            -- ==== DECODE > ====
            DC_RD_ID                : out std_logic_vector(4 downto 0);
            DC_RD_DATA              : out std_logic_vector(31 downto 0);
            DC_RD_WE                : out std_logic
        );
    end component;

    -----------------------------------------------------
    -- SUB-COMPONENTS
    -----------------------------------------------------

    component lagarisc_decode is
        port (
            CLK                     : in std_logic;
            RST                     : in std_logic;

            -- ==== Control & command ====
            FLUSH                   : in std_logic;
            STALL                   : in std_logic;

            -- ==== > FETCH ====
            FETCH_PROGRAM_COUNTER   : in  std_logic_vector(31 downto 0);
            FETCH_INST_DATA         : in  std_logic_vector(31 downto 0);
            FETCH_INST_VALID        : in  std_logic;

            -- ==== REG FILE > ====
            REGFILE_RS1_ID          : out std_logic_vector(4 downto 0); -- WRN: not registered.
            REGFILE_RS2_ID          : out std_logic_vector(4 downto 0); -- WRN: not registered.

            -- ==== EXEC > ====
            -- PC
            EXEC_PROGRAM_COUNTER    : out std_logic_vector(31 downto 0);
            EXEC_BRANCH_OP          : out branch_op_t;
            EXEC_BRANCH_IMM         : out std_logic_vector(31 downto 0);
            EXEC_BRANCH_SRC         : out mux_branch_src_t;
            -- INST FX
            EXEC_INST_F3            : out std_logic_vector(2 downto 0);
            EXEC_INST_F7            : out std_logic_vector(6 downto 0);
            EXEC_INST_VALID         : out std_logic;
            -- RSX
            EXEC_RS1_ID             : out std_logic_vector(4 downto 0);
            EXEC_RS2_ID             : out std_logic_vector(4 downto 0);
            -- RD
            EXEC_RD_ID              : out std_logic_vector(4 downto 0);
            EXEC_RD_WE              : out std_logic;
            -- ALU
            EXEC_ALU_OPC            : out alu_opcode_t;
            EXEC_ALU_IMM            : out std_logic_vector(31 downto 0);
            EXEC_ALU_SHAMT          : out std_logic_vector(4 downto 0);
            EXEC_ALU_OP1_MUX        : out mux_alu_op1_t;
            EXEC_ALU_OP2_MUX        : out mux_alu_op2_t;
            -- MEM
            EXEC_MEM_EN             : out std_logic;
            EXEC_MEM_WE             : out std_logic;
            -- WB MUX
            EXEC_WB_MUX             : out mux_wb_src_t
        );
    end component;

    component lagarisc_regfile is
        port (
            CLK     : in std_logic;
            RST     : in std_logic;

            -- From decode stage
            DC_RS1_ID       : in std_logic_vector(4 downto 0);
            DC_RS2_ID       : in std_logic_vector(4 downto 0);

            -- Register file output
            RS1_DATA        : out std_logic_vector(31 downto 0);
            RS2_DATA        : out std_logic_vector(31 downto 0);

            -- From write back stage
            WB_RD_ID        : in std_logic_vector(4 downto 0);
            WB_RD_DATA      : in std_logic_vector(31 downto 0);
            WB_RD_WE        : in std_logic
        );
    end component;

    component lagarisc_alu is
        port (
            CLK                     : in std_logic;
            RST                     : in std_logic;

            -- ==== Control & command ====
            ALU_READY               : out std_logic;
            STALL                   : in std_logic;

            -- ==== > DECODE ====
            -- PC
            DC_PROGRAM_COUNTER      : in std_logic_vector(31 downto 0);
            -- INST
            DC_ALU_IMM              : in std_logic_vector(31 downto 0);
            -- RSX
            DC_RS1_DATA             : in std_logic_vector(31 downto 0);
            DC_RS2_DATA             : in std_logic_vector(31 downto 0);
            -- ALU
            DC_ALU_OPC              : in alu_opcode_t;
            DC_ALU_SHAMT            : in std_logic_vector(4 downto 0);
            DC_ALU_OP1_MUX          : in mux_alu_op1_t;
            DC_ALU_OP2_MUX          : in mux_alu_op2_t;

            -- ==== MEM > ====
            MEM_ALU_RESULT          : out std_logic_vector(31 downto 0)
        );
    end component;

    -----------------------------------------------------
    -- FUNCTIONS
    -----------------------------------------------------
    -- reverse range of a std logic vector
    function slv_reverse_range(a : in std_logic_vector) return std_logic_vector;

end package;

package body pkg_lagarisc is

    -- reverse range of a std logic vector
    function slv_reverse_range(a : in std_logic_vector) return std_logic_vector is
        variable v_high   : integer := a'high;
        variable v_result : std_logic_vector(a'high downto 0);
    begin
        for i in 0 to v_high loop
            v_result(i) := a(v_high - i);
        end loop;
        return v_result;
    end function;

end package body;