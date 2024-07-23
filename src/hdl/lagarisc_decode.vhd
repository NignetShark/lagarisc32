library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_decode is
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
end entity;


architecture rtl of lagarisc_decode is
    constant C_CONSTANT_4 : std_logic_vector := std_logic_vector(to_signed(4, 32));

    -------------------------------------------------
    -- Signal
    -------------------------------------------------
    signal inst_rs1         : std_logic_vector(4 downto 0);
    signal inst_rs2         : std_logic_vector(4 downto 0);
    signal inst_f7          : std_logic_vector(6 downto 0);
    signal inst_f3          : std_logic_vector(2 downto 0);
    signal inst_rd          : std_logic_vector(4 downto 0);
    signal inst_opcode      : std_logic_vector(6 downto 0);

    signal imm_i            : std_logic_vector(11 downto 0);
    signal imm_b            : std_logic_vector(12 downto 0);
    signal imm_j            : std_logic_vector(20 downto 0);
    signal imm_s            : std_logic_vector(11 downto 0);
    signal imm_u            : std_logic_vector(31 downto 0);
    signal imm_shamt        : std_logic_vector(4 downto 0);

    signal imm_i_signed      : std_logic_vector(31 downto 0);
    signal imm_i_unsigned    : std_logic_vector(31 downto 0);
    signal imm_b_signed      : std_logic_vector(31 downto 0);
    signal imm_j_signed      : std_logic_vector(31 downto 0);

    -------------------------------------------------
    -- Function
    -------------------------------------------------
    function transl_alu_opcode (
        signal p_inst_f3 : in std_logic_vector(2 downto 0);
        signal p_inst_f7 : in std_logic_vector(6 downto 0))
    return alu_opcode_t is
        variable opcode : alu_opcode_t;
    begin
        opcode := ALU_OPCODE_ZERO; -- Used as NOP
        case p_inst_f3 is
            when C_F3_ADD_SUB =>
                if p_inst_f7(5) = '1' then
                    opcode := ALU_OPCODE_SUB;
                else
                    opcode := ALU_OPCODE_ADD;
                end if;
            when C_F3_SLT =>
                opcode := ALU_OPCODE_SLT;
            when C_F3_SLTU =>
                opcode := ALU_OPCODE_SLTU;
            when C_F3_XOR =>
                opcode := ALU_OPCODE_XOR;
            when C_F3_OR =>
                opcode := ALU_OPCODE_OR;
            when C_F3_AND =>
                opcode := ALU_OPCODE_AND;
            when C_F3_SLL =>
                opcode := ALU_OPCODE_SLL;
            when C_F3_SRL_SRA =>
                if p_inst_f7(5) = '1' then
                    opcode := ALU_OPCODE_SRL;
                else
                    opcode := ALU_OPCODE_SRA;
                end if;
            when others =>
                null;
        end case;
        return opcode;
    end function;

    function transl_branch_opcode (
        signal p_inst_f3 : in std_logic_vector(2 downto 0))
    return alu_opcode_t is
        variable opcode : alu_opcode_t;
    begin
        opcode := ALU_OPCODE_ZERO; -- Used as NOP
        case p_inst_f3 is
            when C_F3_BEQ   =>
                opcode := ALU_OPCODE_SEQ;
            when C_F3_BNE   =>
                opcode := ALU_OPCODE_SNE;
            when C_F3_BLT   =>
                opcode := ALU_OPCODE_SLT;
            when C_F3_BGE   =>
                opcode := ALU_OPCODE_SGE;
            when C_F3_BLTU  =>
                opcode := ALU_OPCODE_SLTU;
            when C_F3_BGEU  =>
                opcode := ALU_OPCODE_SGEU;
            when others =>
                null;
        end case;
        return opcode;
    end function;

    function select_imm_i(
        signal p_inst_f3 : in std_logic_vector(2 downto 0);
        signal p_imm_i_signed   : in std_logic_vector(31 downto 0);
        signal p_imm_i_unsigned : in std_logic_vector(31 downto 0))
    return std_logic_vector is
        variable result : std_logic_vector(31 downto 0);
    begin
        case p_inst_f3 is
            -- Unsigned operations
            when C_F3_SLTU | C_F3_BGEU =>
                result := p_imm_i_unsigned;
            -- Signed operations
            when others =>
                result := p_imm_i_signed;
        end case;
        return result;
    end function;

begin

    -- Base Instruction Format (2.2 p11)
    inst_f7             <= FETCH_INST_DATA(31 downto 25);
    inst_rs2            <= FETCH_INST_DATA(24 downto 20);
    inst_rs1            <= FETCH_INST_DATA(19 downto 15);
    inst_f3             <= FETCH_INST_DATA(14 downto 12);
    inst_rd             <= FETCH_INST_DATA(11 downto 7);
    inst_opcode         <= FETCH_INST_DATA(6 downto 0);

    -- Immediate Encoding Variants (2.3 p11)
    imm_i               <= FETCH_INST_DATA(31 downto 20);
    imm_s               <= FETCH_INST_DATA(31 downto 25) & FETCH_INST_DATA(11 downto 7);
    imm_u               <= FETCH_INST_DATA(31 downto 12) & x"000";
    imm_b               <= FETCH_INST_DATA(31) & FETCH_INST_DATA(7) & FETCH_INST_DATA(30 downto 25) & FETCH_INST_DATA(11 downto 8) & "0";
    imm_j               <= FETCH_INST_DATA(31) & FETCH_INST_DATA(19 downto 12) & FETCH_INST_DATA(20) & FETCH_INST_DATA(30 downto 21) & "0";
    imm_shamt           <= FETCH_INST_DATA(24 downto 20);

    imm_i_signed      <= std_logic_vector(resize(signed(imm_i), 32));
    imm_i_unsigned    <= std_logic_vector(resize(unsigned(imm_i), 32));
    imm_b_signed      <= std_logic_vector(resize(signed(imm_b), 32));
    imm_j_signed      <= std_logic_vector(resize(signed(imm_j), 32));

    REGFILE_RS1_ID      <= inst_rs1;
    REGFILE_RS2_ID      <= inst_rs2;

    process(CLK)
        variable decoded_alu_op : alu_opcode_t;
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                -- PC
                EXEC_PROGRAM_COUNTER    <= (others => '-');
                EXEC_BRANCH_OP          <= BRANCH_NOP;
                EXEC_BRANCH_IMM         <= (others => '-');
                EXEC_BRANCH_SRC         <= MUX_BRANCH_SRC_PC;

                -- INST FX
                EXEC_INST_F3            <= (others => '-');
                EXEC_INST_F7            <= (others => '-');
                EXEC_INST_VALID         <= '0';

                -- RSX
                EXEC_RS1_ID             <= (others => '0');
                EXEC_RS2_ID             <= (others => '0');

                -- RD
                EXEC_RD_ID              <= (others => '-');
                EXEC_RD_WE              <= '0';

                -- ALU
                EXEC_ALU_OPC            <= ALU_OPCODE_ZERO;
                EXEC_ALU_IMM            <= (others => '-');
                EXEC_ALU_SHAMT          <= (others => '-');
                EXEC_ALU_OP1_MUX        <= MUX_ALU_OP1_RS1;
                EXEC_ALU_OP2_MUX        <= MUX_ALU_OP2_RS2;

                -- MEM
                EXEC_MEM_EN             <= '0';
                EXEC_MEM_WE             <= '0';

                -- WB MUX
                EXEC_WB_MUX             <= MUX_WB_SRC_ALU;
            else
                -- Decode alu opcode from F3 & F7 informations
                decoded_alu_op := transl_alu_opcode(inst_f3, inst_f7);

                if STALL = '1' then
                    null; -- Bubble
                else
                    -------------------------------------------------
                    -- Default commands
                    -------------------------------------------------
                    -- PC
                    EXEC_PROGRAM_COUNTER    <= FETCH_PROGRAM_COUNTER;
                    EXEC_BRANCH_OP          <= BRANCH_NOP;
                    EXEC_BRANCH_SRC         <= MUX_BRANCH_SRC_PC;

                    -- INST
                    EXEC_INST_F3            <= inst_f3;
                    EXEC_INST_F7            <= inst_f7;
                    EXEC_INST_VALID         <= FETCH_INST_VALID;

                    -- RSX
                    EXEC_RS1_ID             <= inst_rs1;
                    EXEC_RS2_ID             <= inst_rs2;

                    -- RD
                    EXEC_RD_ID              <= inst_rd;
                    EXEC_RD_WE              <= '0';

                    -- ALU
                    EXEC_ALU_OPC            <= ALU_OPCODE_ZERO;
                    EXEC_ALU_SHAMT          <= imm_shamt;
                    EXEC_ALU_OP1_MUX        <= MUX_ALU_OP1_RS1;
                    EXEC_ALU_OP2_MUX        <= MUX_ALU_OP2_RS2;

                    -- MEM
                    EXEC_MEM_EN             <= '0';
                    EXEC_MEM_WE             <= '0';

                    -- WB MUX
                    EXEC_WB_MUX             <= MUX_WB_SRC_ALU;

                    if FETCH_INST_VALID = '1' then

                        -- Valid instruction is ready to be processsed
                        case inst_opcode is
                            -- LUI : Load Upper Immediat
                            when C_OP_LUI =>
                                EXEC_ALU_IMM        <= imm_u;
                                EXEC_ALU_OPC        <= ALU_OPCODE_ADD;
                                EXEC_ALU_OP2_MUX    <= MUX_ALU_OP2_IMM;
                                EXEC_RD_WE          <= '1';

                            -- Integer Register-Register Operations
                            when C_OP_ARTH =>
                                EXEC_ALU_OPC        <= decoded_alu_op;
                                EXEC_RD_WE          <= '1';

                            -- Integer Register-Immediate Instructions
                            when C_OP_ARTHI =>
                                EXEC_ALU_OPC        <= decoded_alu_op;
                                EXEC_ALU_OP2_MUX    <= MUX_ALU_OP2_IMM;
                                EXEC_RD_WE          <= '1';
                                EXEC_ALU_IMM        <= select_imm_i(inst_f3, imm_i_signed, imm_i_unsigned);

                            when C_OP_LOAD =>
                                -- Todo

                            when C_OP_STORE =>
                                -- Todo

                            -- Conditional Branches
                            when C_OP_BRANCH =>
                                EXEC_BRANCH_OP      <= BRANCH_OP_COND;
                                EXEC_BRANCH_IMM     <= imm_b_signed;
                                EXEC_ALU_OPC        <= transl_branch_opcode(inst_f3);

                            when C_OP_JAL =>
                                EXEC_BRANCH_OP      <= BRANCH_OP_UNCOND;
                                EXEC_BRANCH_SRC     <= MUX_BRANCH_SRC_PC;
                                EXEC_BRANCH_IMM     <= imm_j_signed;

                                EXEC_ALU_OPC        <= ALU_OPCODE_ADD;
                                EXEC_ALU_OP1_MUX    <= MUX_ALU_OP1_PC;
                                EXEC_ALU_OP2_MUX    <= MUX_ALU_OP2_IMM;
                                EXEC_ALU_IMM        <= C_CONSTANT_4;

                            when C_OP_JALR =>
                                EXEC_BRANCH_OP      <= BRANCH_OP_UNCOND;
                                EXEC_BRANCH_SRC     <= MUX_BRANCH_SRC_RS1;
                                EXEC_BRANCH_IMM     <= imm_i_signed;

                                EXEC_ALU_OPC        <= ALU_OPCODE_ADD;
                                EXEC_ALU_OP1_MUX    <= MUX_ALU_OP1_PC;
                                EXEC_ALU_IMM        <= C_CONSTANT_4;

                            when others =>
                                null;
                        end case;
                    end if;
                end if;

                if FLUSH = '1' then
                    EXEC_INST_VALID <= '0';
                end if;

            end if;
        end if;
    end process;

end architecture;