library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_supervisor is
    generic(
        G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000"
    );
    port (
        CLK   : in std_logic;
        RST   : in std_logic;

        -- ==== > MEM ====
        MEM_BRANCH_TAKEN    : in std_logic;
        MEM_PC_TAKEN        : in std_logic_vector(31 downto 0);

        -- ==== FETCH > ====
        FETCH_BRANCH_TAKEN  : out std_logic;
        FETCH_PC_TAKEN      : out std_logic_vector(31 downto 0);

        -- ==== Flush ====
        FETCH_FLUSH         : out std_logic;
        DECODE_FLUSH        : out std_logic;
        EXEC_FLUSH          : out std_logic;
        MEM_FLUSH           : out std_logic
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

    signal force_branching    : std_logic;
    signal force_pc           : std_logic_vector(31 downto 0);

begin

    -- Force flush when branch is taken
    FETCH_FLUSH     <= force_fetch_flush  or MEM_BRANCH_TAKEN;
    DECODE_FLUSH    <= force_decode_flush or MEM_BRANCH_TAKEN;
    EXEC_FLUSH      <= force_exec_flush   or MEM_BRANCH_TAKEN;
    MEM_FLUSH       <= force_mem_flush    or MEM_BRANCH_TAKEN;

    -- Supervisor can overload branching operation to force a jump (RESET, IRQ...)
    FETCH_BRANCH_TAKEN <= '1' when force_branching = '1' else MEM_BRANCH_TAKEN;
    FETCH_PC_TAKEN     <= force_pc when force_branching = '1' else MEM_PC_TAKEN;

    process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                -- Start with flush
                fsm <= ST_FLUSH_PIPELINE;

                -- Flush
                force_fetch_flush     <= '1';
                force_decode_flush    <= '1';
                force_exec_flush      <= '1';
                force_mem_flush       <= '1';

                -- Force to start to boot address
                force_pc              <= G_BOOT_ADDR;
                force_branching       <= '1';
            else
                force_fetch_flush     <= '0';
                force_decode_flush    <= '0';
                force_exec_flush      <= '0';
                force_mem_flush       <= '0';

                case fsm is
                    when ST_NOMINAL =>
                        null;

                    when ST_FLUSH_PIPELINE =>
                        -- Flush & Stall
                        force_decode_flush      <= '1';
                        force_exec_flush        <= '1';
                        force_mem_flush         <= '1';
                        -- Disable forced branching
                        force_branching         <= '0';

                        fsm                     <= ST_NOMINAL;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;
end architecture;