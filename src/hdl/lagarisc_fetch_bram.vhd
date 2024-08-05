library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_fetch_bram is
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
end entity;

architecture rtl of lagarisc_fetch_bram is
    signal program_counter          : std_logic_vector(31 downto 0);
    signal fetch_validity_pipeline  : std_logic_vector(G_BRAM_LATENCY - 1 downto 0);

    type pc_pipeline_t is array(0 to G_BRAM_LATENCY - 1) of std_logic_vector(31 downto 0);
    signal pc_pipeline : pc_pipeline_t;

    signal fetch_out_valid_int  : std_logic;
    signal fetch_in_ready_int   : std_logic;

    --signal fetch_en             : std_logic;
    signal bram_addr_int        : std_logic_vector(31 downto 0);
    signal last_bram_dout       : std_logic_vector(31 downto 0);

    signal use_last : std_logic;
begin
    -- Control & cmd
    fetch_out_valid_int      <= fetch_validity_pipeline(G_BRAM_LATENCY - 1);
    fetch_in_ready_int       <= DECODE_IN_READY or not(fetch_out_valid_int);
    -- Output signals

    bram_addr_int           <= SUP_PC_TAKEN when SUP_BRANCH_TAKEN = '1' else program_counter;
    BRAM_ADDR               <= bram_addr_int;
    BRAM_EN                 <= fetch_in_ready_int;

    DC_EXEC_PROGRAM_COUNTER  <= pc_pipeline(G_BRAM_LATENCY - 1);
    DC_INST_DATA             <= last_bram_dout when use_last = '1' else BRAM_DOUT;

    FETCH_IN_READY           <= fetch_in_ready_int;
    FETCH_OUT_VALID          <= fetch_out_valid_int;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                use_last <= '0';

                program_counter <= (others => '0');
                fetch_validity_pipeline <= (others => '0');
                pc_pipeline <= (others => (others => '0'));

                last_bram_dout <= (others => '0');
            else

                if fetch_in_ready_int = '1' then
                    use_last       <= '0';

                    -------------------------------------------------
                    -- Update BRAM pipeline
                    -------------------------------------------------
                    fetch_validity_pipeline(0)  <= '1';
                    pc_pipeline(0)              <= bram_addr_int;
                    for i in 1 to G_BRAM_LATENCY - 1 loop
                        fetch_validity_pipeline(i)  <= fetch_validity_pipeline(i - 1);
                        pc_pipeline(i)              <= pc_pipeline(i - 1);
                    end loop;

                    -------------------------------------------------
                    -- PC: Update to next address
                    -------------------------------------------------
                    -- PC += 4
                    program_counter <= std_logic_vector(unsigned(bram_addr_int) + to_unsigned(4, 32));

                    -------------------------------------------------
                    -- Update validity pipeline when branching
                    -------------------------------------------------
                    if SUP_BRANCH_TAKEN = '1' then
                        -- Clear validity pipeline
                        fetch_validity_pipeline <= (0 => '1', others => '0');
                    end if;

                else
                    if use_last /= '1' then
                        -- Save last bram dout (used to maintain output until handshake)
                        last_bram_dout <= BRAM_DOUT;
                    end if;
                    use_last <= '1';
                end if;
            end if; -- RST
        end if; -- CLK
    end process;
end architecture;