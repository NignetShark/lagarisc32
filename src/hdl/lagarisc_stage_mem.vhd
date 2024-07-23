library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_mem is
    generic (
        G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000"
    );
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        STAGE_READY             : out std_logic;
        STALL                   : in std_logic;
        FLUSH                   : in std_logic;

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
end entity;

architecture rtl of lagarisc_stage_mem is
begin
    process (CLK)
        variable v_branch_taken : std_logic;
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                STAGE_READY             <= '0';

                -- PC
                FETCH_BRANCH_TAKEN      <= '0';
                FETCH_PC_TAKEN          <= (others => '-');
                WB_PC_NOT_TAKEN         <= (others => '-');
                -- RD
                WB_RD_ID                <= (others => '-');
                WB_RD_WE                <= '0';
                -- ALU
                WB_ALU_RESULT           <= (others => '-');
                -- MEM
                WB_MEM_DOUT             <= (others => '-');
                WB_MEM_VALID            <= '0';
                -- WB MUX
                WB_WB_MUX               <= MUX_WB_SRC_ALU;
            else
                STAGE_READY <= '1';
                v_branch_taken := '0';


                if(STALL = '1') then
                    null;
                elsif(EXEC_INST_VALID = '1') then
                    -------------------------------------------------
                    -- Register forwarding
                    -------------------------------------------------
                    -- RD
                    WB_RD_ID                <= EXEC_RD_ID;
                    WB_RD_WE                <= EXEC_RD_WE;
                    -- ALU
                    WB_ALU_RESULT           <= EXEC_ALU_RESULT;
                    -- WB MUX
                    WB_WB_MUX               <= EXEC_WB_MUX;

                    -------------------------------------------------
                    -- PC : Branch evaluation
                    -------------------------------------------------
                    WB_PC_NOT_TAKEN         <= EXEC_PC_NOT_TAKEN;
                    FETCH_PC_TAKEN          <= EXEC_PC_TAKEN;

                    case EXEC_BRANCH_OP is
                        when BRANCH_OP_COND =>
                            v_branch_taken := EXEC_ALU_RESULT(0);
                        when BRANCH_OP_UNCOND =>
                            v_branch_taken := '1';
                        when others =>
                            v_branch_taken := '0';
                    end case;
                    FETCH_BRANCH_TAKEN <= v_branch_taken;

                    if v_branch_taken = '1' then
                        WB_MEM_VALID        <= '0';
                        WB_RD_WE            <= '0';
                    end if;
                else
                    FETCH_BRANCH_TAKEN  <= '0';
                    WB_MEM_VALID        <= '0';
                    WB_RD_WE            <= '0';
                end if;

                if (FLUSH = '1')then
                    FETCH_BRANCH_TAKEN  <= '0';
                    WB_MEM_VALID        <= '0';
                    WB_RD_WE            <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;