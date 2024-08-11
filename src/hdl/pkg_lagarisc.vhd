library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package pkg_lagarisc is

    constant C_NATIVE_SIZE : integer := 32;

    type branch_op_t is (BRANCH_NOP, BRANCH_OP_COND, BRANCH_OP_UNCOND);
    type mux_branch_src_t is (MUX_BRANCH_SRC_PC, MUX_BRANCH_SRC_RS1); -- PC += IMM or PC = RS1 + IMM

    type mux_alu_op1_t is (MUX_ALU_OP1_RS1, MUX_ALU_OP1_PC);
    type mux_alu_op2_t is (MUX_ALU_OP2_RS2, MUX_ALU_OP2_IMM);
    type mux_wb_src_t  is (MUX_WB_SRC_MEM, MUX_WB_SRC_ALU, MUX_WB_SRC_PC, MUX_WB_SRC_CSR);

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
    constant C_OP_SYSTEM    : std_logic_vector(6 downto 0) := "1110011";
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
        ALU_OPCODE_OP1,     -- rd = op1
        ALU_OPCODE_OP2,     -- rd = op2
        ALU_OPCODE_SEQ,     -- rd = (op1 == op2) ? 1:0
        ALU_OPCODE_SNE,     -- rd = (op1 != op2) ? 1:0
        ALU_OPCODE_SGE,     -- rd = (op1 > op2) ? 1:0
        ALU_OPCODE_SGEU     -- rd = (op1 > op2) ? 1:0 [unsigned]
    );

    -----------------------------------------------------
    -- CSR
    -----------------------------------------------------

    -- Machine information
    constant CSR_MVENDORID  : std_logic_vector(11 downto 0) := x"F11"; -- [MRO] Vendor ID
    constant CSR_MARCHID    : std_logic_vector(11 downto 0) := x"F12"; -- [MRO] Architecture ID
    constant CSR_MIMPID     : std_logic_vector(11 downto 0) := x"F13"; -- [MRO] Implementation ID
    constant CSR_MHARTID    : std_logic_vector(11 downto 0) := x"F14"; -- [MRO] Hardware thread ID

    -- Machine trap setup
    constant CSR_MSTATUS    : std_logic_vector(11 downto 0) := x"300"; -- [MRW] Machine status register
    constant CSR_MISA       : std_logic_vector(11 downto 0) := x"301"; -- [MRW] ISA and extensions
    constant CSR_MIE        : std_logic_vector(11 downto 0) := x"304"; -- [MRW] Machine interrupt-enable register
    constant CSR_MTVEC      : std_logic_vector(11 downto 0) := x"305"; -- [MRW] Machine trap-handler base address
    -- constant CSR_MCOUNTEREN : std_logic_vector(11 downto 0) := x"306"; -- [MRW] Machine counter enable.

    -- Machine trap handling
    constant CSR_MSCRATCH  : std_logic_vector(11 downto 0) := x"340"; -- [MRW] Scratch register for machine trap handlers.
    constant CSR_MEPC      : std_logic_vector(11 downto 0) := x"341"; -- [MRW] Machine exception program counter
    constant CSR_MCAUSE    : std_logic_vector(11 downto 0) := x"342"; -- [MRW] Machine trap cause
    constant CSR_MTVAL     : std_logic_vector(11 downto 0) := x"343"; -- [MRW] Machine bad address or instruction
    constant CSR_MIP       : std_logic_vector(11 downto 0) := x"344"; -- [MRW] Machine interrupt pending

    -- Debug trigger
    -- constant CSR_TSELECT   : std_logic_vector(11 downto 0) := x"7A0";
    -- constant CSR_TDATA1    : std_logic_vector(11 downto 0) := x"7A1";
    -- constant CSR_TDATA2    : std_logic_vector(11 downto 0) := x"7A2";
    -- constant CSR_TDATA3    : std_logic_vector(11 downto 0) := x"7A3";
    -- constant CSR_MCONTEXT  : std_logic_vector(11 downto 0) := x"7A8";
    -- constant CSR_SCONTEXT  : std_logic_vector(11 downto 0) := x"7AA";

    -- Const CSR values
    constant CSR_MVENDORID_VALUE  : std_logic_vector(31 downto 0) := (others => '0');
    constant CSR_MARCHID_VALUE    : std_logic_vector(31 downto 0) := x"4C_41_47_41";    -- LAGA
    constant CSR_MIMPID_VALUE     : std_logic_vector(31 downto 0) := (others => '0');   -- Version ?
    constant CSR_MHARTID_VALUE    : std_logic_vector(31 downto 0) := (others => '0');   -- Mono-thread


    type csr_opcode_t is (
        CSR_OPCODE_READ,
        CSR_OPCODE_WRITE,
        CSR_OPCODE_SET,
        CSR_OPCODE_CLEAR
    );


    -----------------------------------------------------
    -- AXI4 constants
    -----------------------------------------------------
    constant C_AXI4_IACCESS     : std_logic_vector(2 downto 0):="100";
    constant C_AXI4_DACCESS     : std_logic_vector(2 downto 0):="000";
    constant C_AXI4_OKAY        : std_logic_vector(1 downto 0):="00";
    constant C_AXI4_EXOKAY      : std_logic_vector(1 downto 0):="01";
    constant C_AXI4_SLVERR      : std_logic_vector(1 downto 0):="10";
    constant C_AXI4_DECERR      : std_logic_vector(1 downto 0):="11";

    -----------------------------------------------------
    -- SUPERVISOR
    -----------------------------------------------------
    component lagarisc_supervisor is
        generic(
            G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000"
        );
        port (
            CLK   : in std_logic;
            RST   : in std_logic;

            -- ==== > MEM ====
            MEM_FLUSH_ACK       : in std_logic;     -- Memory must ack flush before desasserting flush signal (defered flush)
            MEM_BRANCH_TAKEN    : in std_logic;
            MEM_PC_TAKEN        : in std_logic_vector(31 downto 0);

            -- ==== > FETCH > ====
            FETCH_BRANCH_TAKEN  : out std_logic;
            FETCH_PC_TAKEN      : out std_logic_vector(31 downto 0);
            FETCH_BRANCH_READY  : in  std_logic;

            -- ==== Flush ====
            DECODE_FLUSH        : out std_logic;
            EXEC_FLUSH          : out std_logic;
            MEM_FLUSH           : out std_logic;

            -- ==== Stall ====
            MEM_STALL           : out std_logic
        );
    end component;

    -----------------------------------------------------
    -- STAGES
    -----------------------------------------------------
    component lagarisc_fetch_axi4l is
        generic (
            G_NB_ISSUES                 : positive  := 3
        );
        port (
            CLK                         : in std_logic;
            RST                         : in std_logic;

            -- ==== Control & command ====
            FETCH_OUT_VALID             : out std_logic;
            DECODE_IN_READY             : in std_logic;
            FETCH_BRANCH_READY          : out std_logic;

            -- ==== DECODE & EXEC stage > ====
            DC_EXEC_PROGRAM_COUNTER     : out  std_logic_vector(31 downto 0);

            -- ==== DECODE > ====
            DC_INST_DATA                : out  std_logic_vector(31 downto 0);

            -- === > SUPERVISOR ===
            SUP_BRANCH_TAKEN            : in std_logic;
            SUP_PC_TAKEN                : in std_logic_vector(31 downto 0);

            -- ==== AXI4L read interface ====
            AXI_ARVALID                 : out std_logic;
            AXI_ARREADY                 : in  std_logic;
            AXI_ARADDR                  : out std_logic_vector(31 downto 0);
            AXI_ARPROT                  : out std_logic_vector(2 downto 0);
            AXI_RVALID                  : in  std_logic;
            AXI_RREADY                  : out std_logic;
            AXI_RDATA                   : in  std_logic_vector(31 downto 0);
            AXI_RESP                    : in  std_logic_vector(1 downto 0)
        );
    end component;

    component lagarisc_fetch_bram is
        generic (
            G_BRAM_LATENCY  : positive  := 1
        );
        port (
            CLK                         : in std_logic;
            RST                         : in std_logic;

            -- ==== Control & command ====
            FETCH_IN_READY              : out std_logic;
            FETCH_OUT_VALID             : out std_logic;
            DECODE_IN_READY             : in std_logic;

            -- ==== BRAM interface ====
            BRAM_EN                     : out  std_logic;
            BRAM_ADDR                   : out  std_logic_vector(31 downto 0);
            BRAM_DOUT                   : in   std_logic_vector(31 downto 0);

            -- ==== DECODE & EXEC stage > ====
            DC_EXEC_PROGRAM_COUNTER     : out  std_logic_vector(31 downto 0);

            -- ==== DECODE > ====
            DC_INST_DATA                : out  std_logic_vector(31 downto 0);

            -- === > SUPERVISOR ===
            SUP_BRANCH_TAKEN            : in std_logic;
            SUP_PC_TAKEN                : in std_logic_vector(31 downto 0)
        );
    end component;

    component lagarisc_stage_decode is
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
            EXEC_INST_F7            : out std_logic_vector(6 downto 0);
            -- RSX
            EXEC_RS1_ID             : out std_logic_vector(4 downto 0);
            EXEC_RS2_ID             : out std_logic_vector(4 downto 0);
            EXEC_RS1_DATA           : out std_logic_vector(31 downto 0);
            EXEC_RS2_DATA           : out std_logic_vector(31 downto 0);
            -- RD
            EXEC_RD_ID              : out std_logic_vector(4 downto 0);
            EXEC_RD_WE              : out std_logic;
            -- CSR
            EXEC_CSR_ID             : out std_logic_vector(11 downto 0);
            EXEC_CSR_OPCODE         : out csr_opcode_t;
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

            -- ==== Control & command ====
            FLUSH                   : in std_logic;

            DECODE_OUT_VALID        : in std_logic;
            EXEC_IN_READY           : out std_logic;
            EXEC_OUT_VALID          : out std_logic;
            MEM_IN_READY            : in std_logic;

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
            -- CSR
            DC_CSR_ID               : in std_logic_vector(11 downto 0);
            DC_CSR_OPCODE           : in csr_opcode_t;
            -- WB MUX
            DC_WB_MUX               : in mux_wb_src_t;

            -- ==== MEM > ====
            -- PC
            MEM_PC_TAKEN            : out std_logic_vector(31 downto 0);
            MEM_PC_NOT_TAKEN        : out std_logic_vector(31 downto 0); -- PC + 4
            MEM_BRANCH_OP           : out branch_op_t;
            -- INST
            MEM_INST_F3             : out std_logic_vector(2 downto 0);
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
            -- CSR
            MEM_CSR_ID              : out std_logic_vector(11 downto 0);
            MEM_CSR_OPCODE          : out csr_opcode_t;
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

            -- ==== Control & command ====
            STALL                   : in std_logic;
            FLUSH                   : in std_logic;
            FLUSH_ACK               : out std_logic; -- Acknowledge flush (defered flush)

            EXEC_OUT_VALID          : in std_logic;
            MEM_IN_READY            : out std_logic;
            -- WB stage is always read
            -- Mem output is always valid (at least control signals)

            -- ==== > EXEC ====
            -- PC
            EXEC_PC_TAKEN           : in std_logic_vector(31 downto 0);
            EXEC_PC_NOT_TAKEN       : in std_logic_vector(31 downto 0); -- PC + 4
            EXEC_BRANCH_OP          : in branch_op_t;
            -- INST
            EXEC_INST_F3            : in std_logic_vector(2 downto 0);
            -- RD
            EXEC_RD_ID              : in std_logic_vector(4 downto 0);
            EXEC_RD_WE              : in std_logic;
            -- ALU
            EXEC_ALU_RESULT         : in std_logic_vector(31 downto 0);
            -- MEM
            EXEC_MEM_DIN            : in std_logic_vector(31 downto 0);
            EXEC_MEM_EN             : in std_logic;
            EXEC_MEM_WE             : in std_logic;
            -- CSR
            EXEC_CSR_ID             : in std_logic_vector(11 downto 0);
            EXEC_CSR_OPCODE         : in csr_opcode_t;
            -- WB MUX
            EXEC_WB_MUX             : in mux_wb_src_t;

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
            WB_MEM_WE               : out std_logic;
            -- CSR
            WB_CSR_ID               : out std_logic_vector(11 downto 0);
            WB_CSR_OPCODE           : out csr_opcode_t;
            -- WB MUX
            WB_WB_MUX               : out mux_wb_src_t;

            -- ==== SUPERVISOR > ====
            -- PC
            SUP_BRANCH_TAKEN        : out std_logic;
            SUP_PC_TAKEN            : out std_logic_vector(31 downto 0);

            -- ==== > AXI4L interface > ====
            -- write access
            AXI_AWVALID             : out std_logic;
            AXI_AWREADY             : in  std_logic;
            AXI_AWADDR              : out std_logic_vector(31 downto 0);
            AXI_AWPROT              : out std_logic_vector(2 downto 0);
            AXI_WVALID              : out std_logic;
            AXI_WREADY              : in  std_logic;
            AXI_WDATA               : out std_logic_vector(31 downto 0);
            AXI_WSTRB               : out std_logic_vector(3 downto 0);
            AXI_BVALID              : in  std_logic;
            AXI_BREADY              : out std_logic;
            AXI_BRESP               : in  std_logic_vector(1 downto 0);
            --read access
            AXI_ARVALID             : out std_logic;
            AXI_ARREADY             : in  std_logic;
            AXI_ARADDR              : out std_logic_vector(31 downto 0);
            AXI_ARPROT              : out std_logic_vector(2 downto 0);
            AXI_RVALID              : in  std_logic;
            AXI_RREADY              : out std_logic;
            AXI_RDATA               : in  std_logic_vector(31 downto 0);
            AXI_RESP                : in  std_logic_vector(1 downto 0)
        );
    end component;

    component lagarisc_stage_wb is
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
    end component;

    -----------------------------------------------------
    -- SUB-COMPONENTS
    -----------------------------------------------------
    component lagarisc_fetch_issue_fifo is
        generic (
            G_NB_ISSUES                 : positive  := 3
        );
        port (
            CLK                         : in std_logic;
            RST                         : in std_logic;

            ADDR_IN                     : in std_logic_vector(31 downto 0);
            ADDR_OUT                    : out std_logic_vector(31 downto 0);

            PUSH                        : in  std_logic;
            POP                         : in  std_logic;

            IS_FULL                     : out std_logic;
            IS_ALMOST_FULL              : out std_logic;
            IS_EMPTY                    : out std_logic;

            USAGE_CNT                   : out integer range G_NB_ISSUES downto 0
        );
    end component;

    component lagarisc_decode is
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
            -- CSR
            EXEC_CSR_ID             : out std_logic_vector(11 downto 0);
            EXEC_CSR_OPCODE         : out csr_opcode_t;
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
            FLUSH                   : in std_logic;

            DECODE_OUT_VALID        : in std_logic;
            EXEC_IN_READY           : in std_logic;
            ALU_IN_READY            : out std_logic;
            ALU_OUT_VALID           : out std_logic;
            MEM_IN_READY            : in std_logic;

            -- ==== > DECODE ====
            -- PC
            DC_PROGRAM_COUNTER      : in std_logic_vector(31 downto 0);
            -- RSX
            DC_RS1_DATA             : in std_logic_vector(31 downto 0);
            DC_RS2_DATA             : in std_logic_vector(31 downto 0);
            -- ALU
            DC_ALU_OPC              : in alu_opcode_t;
            DC_ALU_IMM              : in std_logic_vector(31 downto 0);
            DC_ALU_SHAMT            : in std_logic_vector(4 downto 0);
            DC_ALU_OP1_MUX          : in mux_alu_op1_t;
            DC_ALU_OP2_MUX          : in mux_alu_op2_t;

            -- ==== MEM > ====
            MEM_ALU_RESULT          : out std_logic_vector(31 downto 0)
        );
    end component;

    component lagarisc_lsu is
        port (
            CLK  : in std_logic;
            RST  : in std_logic;

            -- ==== Control & command ====
            FLUSH                   : in std_logic;
            FLUSH_ACK               : out std_logic; -- Acknowledge flush (defered flush)

            EXEC_OUT_VALID          : in std_logic;
            LSU_IN_READY            : out std_logic;
            MEM_IN_READY            : in  std_logic; -- Loop back
            LSU_OUT_VALID           : out std_logic;

            -- ==== > EXEC ====
            -- INST
            EXEC_INST_F3            : in std_logic_vector(2 downto 0);
            -- MEM
            EXEC_MEM_ADDR           : in std_logic_vector(31 downto 0);
            EXEC_MEM_DIN            : in std_logic_vector(31 downto 0);
            EXEC_MEM_EN             : in std_logic;
            EXEC_MEM_WE             : in std_logic;

            -- ==== WB > ====
            WB_MEM_DOUT             : out std_logic_vector(31 downto 0);
            WB_MEM_WE               : out std_logic;

            -- ==== > AXI4L interface > ====
            -- write access
            AXI_AWVALID             : out std_logic;
            AXI_AWREADY             : in  std_logic;
            AXI_AWADDR              : out std_logic_vector(31 downto 0);
            AXI_AWPROT              : out std_logic_vector(2 downto 0);
            AXI_WVALID              : out std_logic;
            AXI_WREADY              : in  std_logic;
            AXI_WDATA               : out std_logic_vector(31 downto 0);
            AXI_WSTRB               : out std_logic_vector(3 downto 0);
            AXI_BVALID              : in  std_logic;
            AXI_BREADY              : out std_logic;
            AXI_BRESP               : in  std_logic_vector(1 downto 0);
            --read access
            AXI_ARVALID             : out std_logic;
            AXI_ARREADY             : in  std_logic;
            AXI_ARADDR              : out std_logic_vector(31 downto 0);
            AXI_ARPROT              : out std_logic_vector(2 downto 0);
            AXI_RVALID              : in  std_logic;
            AXI_RREADY              : out std_logic;
            AXI_RDATA               : in  std_logic_vector(31 downto 0);
            AXI_RESP                : in  std_logic_vector(1 downto 0)
        );
    end component;

    component lagarisc_csr is
        port (
            CLK  : in std_logic;
            RST  : in std_logic;

            -- ==== > WB ====
            MEM_CSR_ID               : in std_logic_vector(11 downto 0);
            -- INST
            MEM_CSR_OPCODE           : in csr_opcode_t;
            -- RS1 (or immediat)
            MEM_RS1_DATA             : in std_logic_vector(31 downto 0);

            -- ==== REGFILE > ====
            DC_CSR_WE               : out std_logic;
            DC_CSR_DOUT             : out std_logic_vector(31 downto 0)
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