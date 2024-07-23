library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_alu is
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
end entity;

architecture rtl of lagarisc_alu is
    signal op1              : std_logic_vector(31 downto 0);
    signal op1_reversed     : std_logic_vector(31 downto 0);
    signal op2              : std_logic_vector(31 downto 0);
    signal op2_comp2        : std_logic_vector(31 downto 0);

    signal logic_is_equal           : std_logic;
    signal logic_is_lower_signed    : std_logic;
    signal logic_is_lower_unsigned  : std_logic;

begin
    -- OP1
    op1             <= DC_RS1_DATA when DC_ALU_OP1_MUX = MUX_ALU_OP1_RS1 else DC_PROGRAM_COUNTER;
    op1_reversed    <= slv_reverse_range(op1);

    -- OP2
    op2             <= DC_RS2_DATA when DC_ALU_OP2_MUX = MUX_ALU_OP2_RS2 else DC_ALU_IMM;
    op2_comp2       <= std_logic_vector(unsigned(not op2) + 1); -- Two's complement

    -- Logic
    logic_is_equal            <= '1' when unsigned(op1) = unsigned(op2) else '0';
    logic_is_lower_unsigned   <= '1' when signed(op1)   < signed(op2)   else '0';
    logic_is_lower_signed     <= '1' when unsigned(op1) < unsigned(op2) else '0';

    process (CLK)
        variable v_tmp : std_logic_vector(31 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                MEM_ALU_RESULT <= (others => '-');
                ALU_READY           <= '0';
            else
                ALU_READY           <= '1';

                if STALL = '1' then
                    null;
                else
                    case DC_ALU_OPC is
                        --------------------------------------------
                        -- Addition & substraction
                        --------------------------------------------
                        when ALU_OPCODE_ADD | ALU_OPCODE_SUB =>
                            if DC_ALU_OPC = ALU_OPCODE_SUB then
                                -- Substraction
                                v_tmp := op2_comp2;
                            else
                                -- Addition
                                v_tmp := op2;
                            end if;
                            MEM_ALU_RESULT <= std_logic_vector(unsigned(op1) + unsigned(v_tmp));

                        --------------------------------------------
                        -- Set less than (signed/unsigned)
                        --------------------------------------------
                        when ALU_OPCODE_SLT =>
                            MEM_ALU_RESULT <= (0 => logic_is_lower_signed, others => '0');

                        when ALU_OPCODE_SLTU =>
                            MEM_ALU_RESULT <= (0 => logic_is_lower_unsigned, others => '0');

                        --------------------------------------------
                        -- XOR/OR/AND (signed)
                        --------------------------------------------
                        when ALU_OPCODE_XOR =>
                            MEM_ALU_RESULT <= op1 xor op2;
                        when ALU_OPCODE_OR  =>
                            MEM_ALU_RESULT <= op1 or op2;
                        when ALU_OPCODE_AND =>
                            MEM_ALU_RESULT <= op1 and op2;

                        --------------------------------------------
                        -- Shifts : SLL/SRL/SRA
                        --------------------------------------------
                        when ALU_OPCODE_SLL =>
                            null;
                        when ALU_OPCODE_SRL =>
                            null;
                        when ALU_OPCODE_SRA =>
                            null;
                        when ALU_OPCODE_ZERO =>
                            MEM_ALU_RESULT <= (others => '0');
                        when ALU_OPCODE_SEQ =>
                            MEM_ALU_RESULT <= (0 => logic_is_equal, others => '0');
                        when ALU_OPCODE_SNE =>
                            MEM_ALU_RESULT <= (0 => not logic_is_equal, others => '0');
                        when ALU_OPCODE_SGE =>
                            MEM_ALU_RESULT <= (0 => not logic_is_lower_signed, others => '0');
                        when ALU_OPCODE_SGEU =>
                            MEM_ALU_RESULT <= (0 => not logic_is_lower_unsigned, others => '0');
                        when others =>
                            null;
                    end case;
                end if;
            end if; -- RST
        end if; -- CLK
    end process;

end architecture;

