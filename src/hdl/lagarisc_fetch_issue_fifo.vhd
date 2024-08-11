library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_fetch_issue_fifo is
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
end entity;

architecture rtl of lagarisc_fetch_issue_fifo is
    type fifo_mem_t is array(G_NB_ISSUES - 1 downto 0) of std_logic_vector(31 downto 0);
    subtype counter_t is integer range G_NB_ISSUES downto 0;
    subtype pointer_t is integer range (G_NB_ISSUES - 1) downto 0;

    signal fifo_mem  : fifo_mem_t := (others => (others => '-'));

    signal write_ptr : pointer_t;
    signal read_ptr  : pointer_t;

    signal usage_cnt_int : counter_t;

    signal is_full_int  : std_logic;
    signal is_empty_int : std_logic;

    signal valid_push, valid_pop : std_logic;
begin

    IS_FULL <= is_full_int;
    IS_EMPTY <= is_empty_int;
    USAGE_CNT <= usage_cnt_int;

    valid_push <= PUSH and (not (is_full_int and (not POP)));
    valid_pop  <= POP  and (not is_empty_int);

    process(CLK)
        variable read_ptr_fwd : pointer_t;
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                write_ptr       <= 0;
                read_ptr        <= 0;

                usage_cnt_int   <= 0;

                is_full_int     <= '0';
                is_empty_int    <= '1';

                if G_NB_ISSUES = 1 then
                    IS_ALMOST_FULL  <= '1';
                else
                    IS_ALMOST_FULL  <= '0';
                end if;

                ADDR_OUT <= (others => '-');
            else

                if valid_push = '1' and valid_pop = '1' then
                    null; -- Same flags, same usage
                elsif valid_push = '1' then
                    -- Update status flags
                    is_empty_int <= '0';
                    IS_ALMOST_FULL <= '0';
                    if usage_cnt_int = (G_NB_ISSUES - 1) then
                        is_full_int <= '1';
                    end if;
                    if (G_NB_ISSUES > 1) and (usage_cnt_int = (G_NB_ISSUES - 2)) then
                        IS_ALMOST_FULL <= '1';
                    end if;
                    -- Increment counter
                    usage_cnt_int <= usage_cnt_int + 1;
                elsif valid_pop = '1' then
                    -- Update status flags
                    is_full_int <= '0';
                    IS_ALMOST_FULL <= '0';
                    if usage_cnt_int = 1 then
                        is_empty_int <= '1';
                    end if;
                    if usage_cnt_int = G_NB_ISSUES then
                        IS_ALMOST_FULL <= '1';
                    end if;
                    -- Decrement counter
                    usage_cnt_int <= usage_cnt_int - 1;
                end if;

                if valid_push = '1' then
                    if write_ptr = (G_NB_ISSUES - 1) then
                        write_ptr <= 0;
                    else
                        write_ptr <= write_ptr + 1;
                    end if;
                    fifo_mem(write_ptr) <= ADDR_IN;
                end if;

                read_ptr_fwd := read_ptr;
                if valid_pop = '1' then
                    if read_ptr = (G_NB_ISSUES - 1) then
                        read_ptr_fwd := 0;
                    else
                        read_ptr_fwd := read_ptr + 1;
                    end if;
                    read_ptr <= read_ptr_fwd;
                end if;
                ADDR_OUT <= fifo_mem(read_ptr_fwd);

            end if; -- RST
        end if; -- CLK
    end process;
end architecture;