library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_fetch_axi4l is
    generic (
        G_NB_ISSUES                 : positive  := 3
    );
    port (
        CLK                         : in std_logic;
        RST                         : in std_logic;

        -- ==== Control & command ====
        FETCH_OUT_VALID             : out std_logic;
        DECODE_IN_READY             : in std_logic;
        FETCH_BRANCH_READY          : out std_logic;

        -- ==== DECODE & EXEC stage > ====
        DC_EXEC_PROGRAM_COUNTER     : out  std_logic_vector(31 downto 0);

        -- ==== DECODE > ====
        DC_INST_DATA                : out  std_logic_vector(31 downto 0);

        -- === > SUPERVISOR ===
        SUP_BRANCH_TAKEN            : in std_logic;
        SUP_PC_TAKEN                : in std_logic_vector(31 downto 0);

        -- ==== AXI4L read interface ====
        AXI_ARVALID                 : out std_logic;
        AXI_ARREADY                 : in  std_logic;
        AXI_ARADDR                  : out std_logic_vector(31 downto 0);
        AXI_ARPROT                  : out std_logic_vector(2 downto 0);
        AXI_RVALID                  : in  std_logic;
        AXI_RREADY                  : out std_logic;
        AXI_RDATA                   : in  std_logic_vector(31 downto 0);
        AXI_RESP                    : in  std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of lagarisc_fetch_axi4l is
    signal branching_requested : std_logic;
    signal next_pc                      : std_logic_vector(31 downto 0);

    -- Fifo related
    signal fifo_push, fifo_push_available   : std_logic;
    signal fifo_pop                         : std_logic;
    signal fifo_is_empty, fifo_is_almost_full, fifo_is_full  : std_logic;

    signal fifo_usage_cnt       : integer range G_NB_ISSUES downto 0;
    signal flush_cnt            : integer range G_NB_ISSUES downto 0;
    signal flush_cnt_is_zero    : std_logic;

    -- Ctrl & cmd
    signal fetch_out_valid_int  : std_logic;

    -- AXI
    signal axi_araddr_int       : std_logic_vector(31 downto 0);

    signal axi_arvalid_int      : std_logic;
    signal axi_rready_int       : std_logic;

    signal axi_ar_handshake     : std_logic;
    signal axi_r_handshake      : std_logic;

begin
    -- Control & cmd
    fetch_out_valid_int <= AXI_RVALID and (not fifo_is_empty) and flush_cnt_is_zero;

    -- Fifo push is available if :
    -- * fifo pop is asserted (a new place will be available)
    -- * fifo is not full *except* when only one place is available and was taken with a previous push
    fifo_push_available <= ((not fifo_is_full) and (not (fifo_is_almost_full and fifo_push))) or fifo_pop;

    flush_cnt_is_zero   <= '1' when flush_cnt = 0 else '0';

    -- Output signals
    FETCH_OUT_VALID     <= fetch_out_valid_int;
    FETCH_BRANCH_READY  <= not branching_requested;

    DC_INST_DATA        <= AXI_RDATA;

    -- Ready to recv when decode stage is ready or no data was outputed or when flushing axi transaction
    axi_rready_int  <= (DECODE_IN_READY or (not fetch_out_valid_int)) or (not flush_cnt_is_zero);
    AXI_RREADY      <= axi_rready_int;
    AXI_ARVALID     <= axi_arvalid_int;
    AXI_ARADDR      <= axi_araddr_int;
    AXI_ARPROT      <= C_AXI4_IACCESS;

    axi_ar_handshake <= AXI_ARREADY and axi_arvalid_int;
    axi_r_handshake  <= axi_rready_int and AXI_RVALID;
    fifo_pop         <= axi_r_handshake;

    process(CLK)
        variable pc_src : std_logic_vector(31 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                fifo_push <= '0';

                axi_araddr_int  <= (others => '-');
                axi_arvalid_int <= '0';

                branching_requested <= '0';
            else
                fifo_push <= '0';

                ----------------------------------------------
                -- Clear pending address read transaction
                ----------------------------------------------
                if axi_ar_handshake = '1' then
                    axi_arvalid_int <= '0';
                end if;

                ----------------------------------------------
                -- Handle read transaction result
                ----------------------------------------------
                if axi_r_handshake = '1' then
                    if flush_cnt_is_zero /= '1' then
                        flush_cnt <= flush_cnt - 1;
                    end if;
                end if;

                ----------------------------------------------
                -- Generate new AXI4 transaction
                ----------------------------------------------
                if ((axi_ar_handshake = '1') or (axi_arvalid_int = '0')) and (fifo_push_available = '1') then
                    -------------------------------------------------
                    -- PC: Update to next address
                    -------------------------------------------------
                    branching_requested <= '0';

                    pc_src := next_pc;
                    if SUP_BRANCH_TAKEN = '1' then
                        pc_src              := SUP_PC_TAKEN;
                        flush_cnt           <= fifo_usage_cnt;
                    end if;

                    next_pc <= std_logic_vector(unsigned(pc_src) + to_unsigned(4, 32));

                    -- Address is aligned with a 32bit word.
                    axi_araddr_int <= (others => '0');
                    axi_araddr_int(31 downto 2) <= pc_src(31 downto 2);

                    axi_arvalid_int <= '1';

                    fifo_push       <= '1';

                elsif SUP_BRANCH_TAKEN = '1' then
                    if branching_requested = '0' then
                        branching_requested <= '1';
                        flush_cnt           <= fifo_usage_cnt; -- Start flushing requested addresses
                        next_pc             <= SUP_PC_TAKEN;
                    end if;
                end if;

            end if; -- RST
        end if; -- CLK
    end process;

    inst_issue_fifo : lagarisc_fetch_issue_fifo
        generic map (
            G_NB_ISSUES                 => G_NB_ISSUES
        )
        port map (
            CLK                         => CLK,
            RST                         => RST,

            ADDR_IN                     => axi_araddr_int,
            ADDR_OUT                    => DC_EXEC_PROGRAM_COUNTER,

            PUSH                        => fifo_push,
            POP                         => fifo_pop,

            IS_FULL                     => fifo_is_full,
            IS_ALMOST_FULL              => fifo_is_almost_full,
            IS_EMPTY                    => fifo_is_empty,

            USAGE_CNT                   => fifo_usage_cnt
        );
end architecture;