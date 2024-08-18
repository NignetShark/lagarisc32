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
        FLUSH                   : in std_logic;

        DECODE_OUT_VALID        : in std_logic;
        EXEC_IN_READY           : in std_logic; -- Stage readiness
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
end entity;

architecture rtl of lagarisc_alu is
    type alu_fsm_t is (ST_ALU_FETCH, ST_ALU_SHIFTING);
    signal alu_fsm : alu_fsm_t;

    signal alu_busy_int         : std_logic;
    signal alu_out_valid_int    : std_logic;
    signal alu_in_ready_int     : std_logic;

    signal op1                  : std_logic_vector(31 downto 0);
    signal op1_reversed         : std_logic_vector(31 downto 0);
    signal op2                  : std_logic_vector(31 downto 0);
    signal op2_comp2            : std_logic_vector(31 downto 0);
    signal shamt                : std_logic_vector(4 downto 0);

    signal logic_is_equal           : std_logic;
    signal logic_is_lower_signed    : std_logic;
    signal logic_is_lower_unsigned  : std_logic;

    signal bitshift_value   : std_logic_vector(31 downto 0);
    signal bitshift_counter : unsigned(4 downto 0);
    signal bitshift_msb     : std_logic;
    signal bitshift_reverse : std_logic;

begin

    -- Ctrl & cmd
    alu_in_ready_int <= (MEM_IN_READY or (not alu_out_valid_int)) and (not alu_busy_int);

    -- OP1
    op1             <= DC_RS1_DATA when DC_ALU_OP1_MUX = MUX_ALU_OP1_RS1 else DC_PROGRAM_COUNTER;
    op1_reversed    <= slv_reverse_range(op1);

    -- OP2
    op2             <= DC_RS2_DATA when DC_ALU_OP2_MUX = MUX_ALU_OP2_RS2 else DC_ALU_IMM;
    op2_comp2       <= std_logic_vector(unsigned(not op2) + 1); -- Two's complement

    -- Shamt
    shamt           <= DC_RS2_DATA(4 downto 0) when DC_ALU_OP2_MUX = MUX_ALU_OP2_RS2 else DC_ALU_SHAMT;

    -- Logic
    logic_is_equal              <= '1' when unsigned(op1) = unsigned(op2) else '0';
    logic_is_lower_signed       <= '1' when signed(op1)   < signed(op2)   else '0';
    logic_is_lower_unsigned     <= '1' when unsigned(op1) < unsigned(op2) else '0';

    ALU_OUT_VALID   <= alu_out_valid_int;
    ALU_IN_READY    <= alu_in_ready_int;

    process (CLK)
        variable v_tmp : std_logic_vector(31 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                alu_fsm <= ST_ALU_FETCH;
                alu_busy_int <= '0';
                alu_out_valid_int <= '0';

                MEM_ALU_RESULT <= (others => '-');

                bitshift_counter    <= (others => '-');
                bitshift_value      <= (others => '-');
                bitshift_msb        <= '-';
                bitshift_reverse    <= '-';
            else
                if (MEM_IN_READY = '1') and (alu_out_valid_int = '1') then
                    alu_out_valid_int <= '0';
                end if;

                case alu_fsm is
                    when ST_ALU_FETCH =>
                        if (DECODE_OUT_VALID = '1') and (EXEC_IN_READY = '1') then
                            -- By default, an output will be generated
                            alu_out_valid_int <= '1';




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
                                when ALU_OPCODE_SLL  =>

                                    bitshift_counter    <= unsigned(shamt);
                                    bitshift_value      <= op1;
                                    bitshift_msb        <= '0';
                                    bitshift_reverse    <= '0';

                                    alu_busy_int <= '1';
                                    alu_out_valid_int <= '0';
                                    alu_fsm <= ST_ALU_SHIFTING;

                                when ALU_OPCODE_SRL =>

                                    bitshift_counter    <= unsigned(shamt);
                                    bitshift_value      <= op1_reversed;
                                    bitshift_msb        <= '0';
                                    bitshift_reverse    <= '1';

                                    alu_busy_int <= '1';
                                    alu_out_valid_int <= '0';
                                    alu_fsm <= ST_ALU_SHIFTING;

                                when ALU_OPCODE_SRA =>

                                    bitshift_counter    <= unsigned(shamt);
                                    bitshift_value      <= op1_reversed;
                                    bitshift_msb        <= op1(31);
                                    bitshift_reverse    <= '1';

                                    alu_busy_int <= '1';
                                    alu_out_valid_int <= '0';
                                    alu_fsm <= ST_ALU_SHIFTING;


                                --------------------------------------------
                                -- Extended operation
                                --------------------------------------------
                                when ALU_OPCODE_OP1 =>
                                    MEM_ALU_RESULT <= op1;
                                when ALU_OPCODE_OP2 =>
                                    MEM_ALU_RESULT <= op2;
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

                    when ST_ALU_SHIFTING =>

                        if bitshift_counter /= 0 then
                            -- Shitfting by one bit
                            bitshift_value      <= bitshift_value(30 downto 0) & bitshift_msb;
                            bitshift_counter    <= bitshift_counter - 1;
                        else
                            -- Shifting done => send to output
                            if bitshift_reverse = '1' then
                                MEM_ALU_RESULT <= slv_reverse_range(bitshift_value);
                            else
                                MEM_ALU_RESULT <= bitshift_value;
                            end if;

                            alu_busy_int <= '0';
                            alu_out_valid_int <= '1';

                            alu_fsm <= ST_ALU_FETCH;
                        end if;
                end case;

                if FLUSH = '1' then
                    alu_fsm <= ST_ALU_FETCH;
                    alu_busy_int <= '0';
                    alu_out_valid_int <= '0';
                end if;
            end if; -- RST
        end if; -- CLK
    end process;


end architecture;

