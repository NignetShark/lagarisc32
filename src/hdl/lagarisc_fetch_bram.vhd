library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_fetch_bram is
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
end entity;

architecture rtl of lagarisc_fetch_bram is
    signal program_counter          : std_logic_vector(31 downto 0);
    signal fetch_validity_pipeline  : std_logic_vector(G_BRAM_LATENCY - 1 downto 0);

    type pc_pipeline_t is array(0 to G_BRAM_LATENCY - 1) of std_logic_vector(31 downto 0);
    signal pc_pipeline : pc_pipeline_t;

    signal fetch_en     : std_logic;
    signal inst_valid   : std_logic;
    signal last_bram_dout : std_logic_vector(31 downto 0);
begin
    -- Internal signals
    inst_valid   <= fetch_validity_pipeline(G_BRAM_LATENCY - 1);
    fetch_en     <= not STALL;

    -- Output signals
    STAGE_READY             <= '1';

    BRAM_ADDR               <= program_counter;
    BRAM_EN                 <= fetch_en;

    DC_EXEC_PROGRAM_COUNTER  <= pc_pipeline(G_BRAM_LATENCY - 1);
    DC_INST_DATA             <= last_bram_dout when STALL = '1' else BRAM_DOUT;
    DC_INST_VALID            <= inst_valid;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                program_counter <= G_BOOT_ADDR;
                fetch_validity_pipeline <= (others => '0');
                pc_pipeline <= (others => (others => '0'));
                last_bram_dout <= (others => '0');
            else

                if STALL = '1' then
                    -- Fetch is stalled, the last intruction must be yield
                    -- during this event.
                    null;
                else
                    last_bram_dout <= BRAM_DOUT;

                    -------------------------------------------------
                    -- PC: Update to next address
                    -------------------------------------------------
                    if MEM_BRANCH_TAKEN = '1' then
                        -- taken : PC = branch address
                        program_counter <= MEM_PC_TAKEN;
                    else
                        -- not taken : PC += 4
                        program_counter <= std_logic_vector(unsigned(program_counter) + to_unsigned(4, 32));
                    end if;

                    -------------------------------------------------
                    -- Compute instruction validity from BRAM latency
                    -------------------------------------------------
                    if FLUSH = '1' then
                        fetch_validity_pipeline <= (others => '0');
                    else
                        fetch_validity_pipeline(0) <= '1';

                        pc_pipeline(0)             <= program_counter;
                        for i in 1 to G_BRAM_LATENCY - 1 loop
                            fetch_validity_pipeline(i)  <= fetch_validity_pipeline(i - 1);
                            pc_pipeline(i)              <= pc_pipeline(i - 1);
                        end loop;
                    end if;

                end if;

            end if;
        end if;
    end process;
end architecture;