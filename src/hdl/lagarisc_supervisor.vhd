library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_supervisor is
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
end entity;

architecture rtl of lagarisc_supervisor is
    type supervisor_fsm_t is (
        ST_NOMINAL,
        ST_FLUSH_PIPELINE
        );

    signal fsm : supervisor_fsm_t;

    signal force_fetch_flush  : std_logic;
    signal force_decode_flush : std_logic;
    signal force_exec_flush   : std_logic;
    signal force_mem_flush    : std_logic;

begin

    FETCH_FLUSH     <= force_fetch_flush  or MEM_BRANCH_TAKEN;
    DECODE_FLUSH    <= force_decode_flush or MEM_BRANCH_TAKEN;
    EXEC_FLUSH      <= force_exec_flush   or MEM_BRANCH_TAKEN;
    MEM_FLUSH       <= force_mem_flush    or MEM_BRANCH_TAKEN;

    process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                fsm <= ST_FLUSH_PIPELINE;
                -- Flush
                force_fetch_flush     <= '0';
                force_decode_flush    <= '0';
                force_exec_flush      <= '0';
                force_mem_flush       <= '0';
                -- Fetch
                FETCH_STALL     <= '1';
                DECODE_STALL    <= '1';
                EXEC_STALL      <= '1';
                MEM_STALL       <= '1';
            else
                force_fetch_flush     <= '0';
                force_decode_flush    <= '0';
                force_exec_flush      <= '0';
                force_mem_flush       <= '0';

                FETCH_STALL     <= '0';
                DECODE_STALL    <= '0';
                EXEC_STALL      <= '0';
                MEM_STALL       <= '0';

                case fsm is
                    when ST_NOMINAL =>
                        null;

                    when ST_FLUSH_PIPELINE =>
                        -- Flush & Stall
                        force_decode_flush      <= '1';
                        force_exec_flush        <= '1';
                        force_mem_flush         <= '1';
                        fsm                     <= ST_NOMINAL;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
end architecture;