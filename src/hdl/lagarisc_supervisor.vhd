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
        MEM_FLUSH_ACK       : in std_logic;     -- Memory must ack flush before desasserting flush signal (defered flush)
        MEM_BRANCH_TAKEN    : in std_logic;
        MEM_PC_TAKEN        : in std_logic_vector(31 downto 0);

        -- ==== > FETCH > ====
        FETCH_IN_READY      : in std_logic;
        FETCH_BRANCH_TAKEN  : out std_logic;
        FETCH_PC_TAKEN      : out std_logic_vector(31 downto 0);

        -- ==== Flush ====
        DECODE_FLUSH        : out std_logic;
        EXEC_FLUSH          : out std_logic;
        MEM_FLUSH           : out std_logic;

        -- ==== Stall ====
        MEM_STALL           : out std_logic
    );
end entity;

architecture rtl of lagarisc_supervisor is

    type supervisor_fsm_t is (
        ST_INIT,
        ST_NOMINAL);

    signal fsm : supervisor_fsm_t;

    signal flush_defered        : std_logic;
    signal flush_int            : std_logic;
    signal force_flush          : std_logic;

    signal force_branch             : std_logic;
    signal force_branch_addr        : std_logic_vector(31 downto 0);

    signal fetch_branch_taken_int : std_logic;

begin
    -- Force flush when branch is taken
    flush_int  <= force_flush or flush_defered or MEM_BRANCH_TAKEN;

    DECODE_FLUSH    <= flush_int;
    EXEC_FLUSH      <= flush_int;
    MEM_FLUSH       <= flush_int;

    -- Supervisor can overload branching operation to force a jump (RESET, IRQ...)
    fetch_branch_taken_int <= '1' when force_branch = '1' else MEM_BRANCH_TAKEN;
    FETCH_BRANCH_TAKEN <= fetch_branch_taken_int;
    FETCH_PC_TAKEN     <= force_branch_addr when force_branch = '1' else MEM_PC_TAKEN;

    process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                -- Start with flush
                fsm <= ST_INIT;

                -- Flush & jump
                force_flush <= '1';

                -- Force to start to boot address
                force_branch        <= '1';
                force_branch_addr   <= G_BOOT_ADDR;

                MEM_STALL <= '0';
            else
                force_flush    <= '0';
                force_branch   <= '0';
                MEM_STALL      <= '0';

                case fsm is
                    when ST_INIT =>
                        force_flush         <= '1';
                        force_branch        <= '1';
                        force_branch_addr   <= G_BOOT_ADDR;

                        -- Wait until fetch stage is ready to jump
                        if FETCH_IN_READY = '1' then
                            fsm  <= ST_NOMINAL;
                        end if;

                    when ST_NOMINAL =>
                        -- Regulation between Mem branching <=> fetch
                        if MEM_BRANCH_TAKEN = '1' and FETCH_IN_READY = '0' then
                            -- Stall memory stage until fetch is ready to take the branch
                            MEM_STALL <= '1';
                        end if;

                    when others =>
                        null;
                end case;

            end if;
        end if;
    end process;

    P_FLUSH_DEFERED : process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                flush_defered       <= '0';
            else
                if flush_defered = '1' then
                    -- Wait acknowledgement from memory stage
                    if (MEM_FLUSH_ACK = '1') then
                        flush_defered <= '0';
                    end if;
                else
                    if flush_int = '1' and MEM_FLUSH_ACK = '0' then
                        -- No ack receved from memory stage:
                        -- memory wants to defered the flush if a transaction is ongoing
                        flush_defered <= '1';
                    end if;
                end if;

            end if;
        end if;
    end process;

end architecture;