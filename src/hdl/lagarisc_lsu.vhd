library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_lsu is
    port (
        CLK  : in std_logic;
        RST  : in std_logic;

        -- ==== Control & command ====
        FLUSH                   : in std_logic;
        FLUSH_ACK               : out std_logic; -- Acknowledge flush (defered flush)

        EXEC_OUT_VALID          : in std_logic;
        LSU_IN_READY            : out std_logic;
        MEM_IN_READY            : in  std_logic; -- Loop back
        LSU_OUT_VALID           : out std_logic;

        -- ==== > EXEC ====
        -- INST
        EXEC_INST_F3            : in std_logic_vector(2 downto 0);
        -- LSU
        EXEC_LSU_ADDR           : in std_logic_vector(31 downto 0);
        EXEC_LSU_DIN            : in std_logic_vector(31 downto 0);
        EXEC_LSU_EN             : in std_logic;
        EXEC_LSU_WE             : in std_logic;

        -- ==== WB > ====
        WB_LSU_DOUT             : out std_logic_vector(31 downto 0);
        WB_LSU_WE               : out std_logic;

        -- ==== > AXI4L interface > ====
        -- write access
        AXI_AWVALID             : out std_logic;
        AXI_AWREADY             : in  std_logic;
        AXI_AWADDR              : out std_logic_vector(31 downto 0);
        AXI_AWPROT              : out std_logic_vector(2 downto 0);
        AXI_WVALID              : out std_logic;
        AXI_WREADY              : in  std_logic;
        AXI_WDATA               : out std_logic_vector(31 downto 0);
        AXI_WSTRB               : out std_logic_vector(3 downto 0);
        AXI_BVALID              : in  std_logic;
        AXI_BREADY              : out std_logic;
        AXI_BRESP               : in  std_logic_vector(1 downto 0);
        --read access
        AXI_ARVALID             : out std_logic;
        AXI_ARREADY             : in  std_logic;
        AXI_ARADDR              : out std_logic_vector(31 downto 0);
        AXI_ARPROT              : out std_logic_vector(2 downto 0);
        AXI_RVALID              : in  std_logic;
        AXI_RREADY              : out std_logic;
        AXI_RDATA               : in  std_logic_vector(31 downto 0);
        AXI_RESP                : in  std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of lagarisc_lsu is

    constant C_STRB_BYTE        : std_logic_vector(1 downto 0):="00";
    constant C_STRB_HALF        : std_logic_vector(1 downto 0):="01";
    constant C_STRB_FULL        : std_logic_vector(1 downto 0):="10";

    signal lsu_busy             : std_logic;
    signal lsu_in_ready_int     : std_logic;
    signal lsu_valid_mem_en     : std_logic;

    signal mem_addr_aligned     : std_logic_vector(31 downto 0);
    signal mem_addr_offset      : integer range 3 downto 0;
    signal mem_addr_offset_reg  : integer range 3 downto 0;
    signal exec_inst_f3_reg     : std_logic_vector(2 downto 0);


    signal axi_awvalid_int   : std_logic;
    signal axi_wvalid_int    : std_logic;
    signal axi_bready_int    : std_logic;
    signal axi_arvalid_int   : std_logic;
    signal axi_rready_int    : std_logic;

    signal axi_aw_handshake : std_logic;
    signal axi_w_handshake  : std_logic;
    signal axi_b_handshake  : std_logic;
    signal axi_ar_handshake : std_logic;
    signal axi_r_handshake  : std_logic;
    signal axi_r_handshake_reg  : std_logic;


begin

    -- Control & cmd
    FLUSH_ACK           <= FLUSH and (not lsu_busy);
    lsu_in_ready_int    <= not(lsu_busy);
    LSU_IN_READY        <= lsu_in_ready_int;

    lsu_valid_mem_en    <= (EXEC_LSU_EN and EXEC_OUT_VALID) and not(FLUSH);

    -- Memory alignment
    mem_addr_aligned    <= EXEC_LSU_ADDR(31 downto 2) & "00";
    mem_addr_offset     <= to_integer(unsigned(EXEC_LSU_ADDR(1 downto 0)));

    -- AXI4 handshakes
    axi_aw_handshake    <= axi_awvalid_int and AXI_AWREADY;
    axi_w_handshake     <= axi_wvalid_int and AXI_WREADY;
    axi_b_handshake     <= axi_bready_int and AXI_BVALID;
    axi_ar_handshake    <= axi_arvalid_int and AXI_ARREADY;
    axi_r_handshake     <= axi_rready_int and AXI_RVALID;

    -- AXI4 write
    AXI_AWVALID         <= axi_awvalid_int;
    AXI_AWPROT          <= C_AXI4_DACCESS;
    AXI_WVALID          <= axi_wvalid_int;
    AXI_BREADY          <= axi_bready_int;

    -- AXI4 read
    AXI_ARVALID         <= axi_arvalid_int;
    AXI_ARPROT          <= C_AXI4_DACCESS;
    AXI_RREADY          <= axi_rready_int;

    P_LSU_FSM: process (clk)
    begin
        if rising_edge(clk) then
            if RST = '1' then
                exec_inst_f3_reg     <= (others => '0');
                mem_addr_offset_reg  <= 0;

                -- Control & cmd
                LSU_OUT_VALID <= '0';
                lsu_busy <= '0';

                -- Registered output
                WB_LSU_WE   <= '0';
                WB_LSU_DOUT <= (others => '-');

                -- AXI signals
                AXI_AWADDR  <= (others => '-');
                axi_awvalid_int <= '0';
                AXI_WDATA   <= (others => '-');
                AXI_WSTRB   <= (others => '0');
                axi_bready_int  <= '0';
                AXI_ARADDR  <= (others => '-');
                axi_arvalid_int <= '0';
                axi_rready_int  <= '0';
                axi_r_handshake_reg <= '0';

            else
                -- Default values
                LSU_OUT_VALID   <= '0';
                axi_r_handshake_reg <= axi_r_handshake;

                ----------------------------------------------
                -- Clear pending address read transaction
                ----------------------------------------------
                if axi_ar_handshake = '1' then
                    axi_arvalid_int <= '0';
                end if;

                ----------------------------------------------
                -- Clear pending address write transaction
                ----------------------------------------------
                if axi_aw_handshake = '1' then
                    axi_awvalid_int <= '0';
                end if;

                ----------------------------------------------
                -- Clear pending write transaction
                ----------------------------------------------
                if axi_w_handshake = '1' then
                    axi_wvalid_int <= '0';
                end if;

                ----------------------------------------------
                -- Handle read transaction result
                ----------------------------------------------
                if axi_r_handshake = '1' then
                    axi_rready_int <= '0';
                    LSU_OUT_VALID  <= '1';
                    lsu_busy <= '0';

                    -- Process read data & realign
                    case exec_inst_f3_reg(1 downto 0) is
                        when C_STRB_BYTE =>
                            if exec_inst_f3_reg(2) = '1' then
                                WB_LSU_DOUT <= std_logic_vector(resize(unsigned(AXI_RDATA((8 * (mem_addr_offset_reg + 1)) - 1 downto 8 * mem_addr_offset_reg)), 32));
                            else
                                WB_LSU_DOUT <= std_logic_vector(resize(signed(AXI_RDATA((8 * (mem_addr_offset_reg + 1)) - 1 downto 8 * mem_addr_offset_reg)), 32));
                            end if;

                        when C_STRB_HALF =>
                            if exec_inst_f3_reg(2) = '1' then
                                WB_LSU_DOUT <= std_logic_vector(resize(unsigned(AXI_RDATA((8 * (mem_addr_offset_reg + 2)) - 1 downto 8 * mem_addr_offset_reg)), 32));
                            else
                                WB_LSU_DOUT <= std_logic_vector(resize(signed(AXI_RDATA((8 * (mem_addr_offset_reg + 2)) - 1 downto 8 * mem_addr_offset_reg)), 32));
                            end if;

                        when others => -- C_STRB_FULL
                            WB_LSU_DOUT <= AXI_RDATA;
                    end case;

                    -- Handle read error
                    if AXI_RESP /= C_AXI4_EXOKAY then
                        -- TODO: handle error
                    end if;

                    -- The LSU will take an extra clock cycle
                    -- in order to geneate a memory write to WB stage
                end if;

                ----------------------------------------------
                -- Handle write transaction result
                ----------------------------------------------
                if axi_b_handshake = '1' then
                    lsu_busy <= '0';
                    axi_bready_int <= '0';
                    LSU_OUT_VALID  <= '1';

                    -- Handle write error
                    if AXI_BRESP /= C_AXI4_EXOKAY then
                        -- TODO: handle error
                    end if;

                end if;

                ----------------------------------------------
                -- Generate new AXI4 transaction
                ----------------------------------------------
                if (MEM_IN_READY = '1') and (lsu_valid_mem_en = '1') then
                    lsu_busy <= '1';

                    -- Save strb informations
                    exec_inst_f3_reg    <= EXEC_INST_F3;
                    mem_addr_offset_reg <= mem_addr_offset;

                    if EXEC_LSU_WE = '1' then
                        -- Start a new WRITE transaction
                        AXI_AWADDR      <= mem_addr_aligned;
                        AXI_WDATA       <= (others => '0');
                        AXI_WSTRB       <= (others => '0');
                        axi_awvalid_int <= '1';
                        axi_wvalid_int  <= '1';
                        axi_bready_int  <= '1';

                        -- Realign write data according to strobe
                        case EXEC_INST_F3(1 downto 0) is
                            when C_STRB_BYTE    =>
                                AXI_WSTRB(mem_addr_offset) <= '1';
                                AXI_WDATA((8 * (mem_addr_offset + 1)) - 1 downto 8 * mem_addr_offset) <= EXEC_LSU_DIN(7 downto 0);
                            when C_STRB_HALF    =>
                                AXI_WSTRB((mem_addr_offset + 1) downto mem_addr_offset) <= "11";
                                AXI_WDATA((8 * (mem_addr_offset + 2)) - 1 downto 8 * mem_addr_offset) <= EXEC_LSU_DIN(15 downto 0);
                            when others => -- C_STRB_FULL
                                AXI_WSTRB <= (others => '1');
                                AXI_WDATA <= EXEC_LSU_DIN;
                        end case;
                    else
                        -- Start a new READ transaction
                        AXI_ARADDR  <= mem_addr_aligned;
                        axi_arvalid_int <= '1';
                        axi_rready_int  <= '1';
                    end if;
                end if;

                ----------------------------------------------
                -- Handle flush (/!\ can be defered)
                ----------------------------------------------
                if FLUSH = '1' then
                    if lsu_busy = '1' then
                        null; -- Defered flush : wait AXI transaction to end
                    else
                        LSU_OUT_VALID <= '0';
                    end if;
                end if;

            end if;
        end if;
    end process P_LSU_FSM;

end architecture;