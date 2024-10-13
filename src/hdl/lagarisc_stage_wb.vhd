library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_wb is
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        -- ==== Control & command ====
        MEM_OUT_VALID          : in std_logic;

        -- ==== > MEM ====
        -- RD
        MEM_RD_ID               : in std_logic_vector(4 downto 0);
        MEM_RD_WE               : in std_logic;
        MEM_RD_DATA             : in std_logic_vector(31 downto 0);
        -- CSR
        MEM_CSR_ID              : in std_logic_vector(11 downto 0);
        MEM_CSR_OPCODE          : in csr_opcode_t;
        -- WB
        MEM_WB_MUX              : in mux_wb_src_t;

        -- ==== DECODE > ====
        DC_RD_ID                : out std_logic_vector(4 downto 0);
        DC_RD_DATA              : out std_logic_vector(31 downto 0);
        DC_RD_WE                : out std_logic;
        DC_RD_VALID             : out std_logic
    );
end entity;

architecture rtl of lagarisc_stage_wb is
    signal dc_csr_dout : std_logic_vector(31 downto 0);
    signal dc_csr_we   : std_logic;

    signal dc_rd_valid_int   : std_logic;
    signal dc_rd_we_int   : std_logic;
    signal dc_rd_data_int : std_logic_vector(31 downto 0);
    signal dc_rd_data_reg : std_logic_vector(31 downto 0);
begin
    DC_RD_ID    <=  MEM_RD_ID;

    -- DATA
    dc_rd_data_int  <=  dc_csr_dout     when MEM_WB_MUX = MUX_WB_SRC_CSR else
                        MEM_RD_DATA;    -- others (LSU & ALU)

    -- WE
    dc_rd_we_int    <=  dc_csr_we       when MEM_WB_MUX = MUX_WB_SRC_CSR else
                        MEM_RD_WE;      -- others (LSU & ALU)

    -- VALID
    dc_rd_valid_int <=  '1'             when MEM_WB_MUX = MUX_WB_SRC_CSR else  -- CSR is always valid.
                        MEM_OUT_VALID;  -- others (LSU & ALU)

    -- Outputs
    DC_RD_DATA      <=  dc_rd_data_int when dc_rd_we_int = '1' else dc_rd_data_reg; -- Required for RD forwarding
    DC_RD_WE        <=  dc_rd_we_int;
    DC_RD_VALID     <=  dc_rd_valid_int;

    -----------------------------------------
    -- Registering RD_DATA when WE
    -----------------------------------------
    process(CLK) is
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                dc_rd_data_reg <= (others => '-');
            else
                if dc_rd_we_int = '1' then
                    dc_rd_data_reg <= dc_rd_data_int;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------
    -- CSR registers
    -----------------------------------------
    inst_csr : lagarisc_csr
        port map(
            CLK                 => CLK,
            RST                 => RST,

            -- ==== Control & command ====
            MEM_OUT_VALID       => MEM_OUT_VALID,

            -- ==== > WB ====
            MEM_CSR_ID          => MEM_CSR_ID,
            -- INST
            MEM_CSR_OPCODE      => MEM_CSR_OPCODE,
            -- RS1 (or immediat)
            MEM_RS1_DATA        => MEM_RD_DATA,

            -- ==== REGFILE > ====
            DC_CSR_WE           => dc_csr_we,  -- /!\ Output combinatorial (required for CSR atomicity)
            DC_CSR_DOUT         => dc_csr_dout -- /!\ Output combinatorial (required for CSR atomicity)
        );

end architecture;