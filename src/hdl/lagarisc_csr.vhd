library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_csr is
    port (
        CLK  : in std_logic;
        RST  : in std_logic;

        -- ==== > WB ====
        MEM_CSR_ID               : in std_logic_vector(11 downto 0);
        -- INST
        MEM_CSR_OPCODE           : in csr_opcode_t;
        -- RS1 (or immediat)
        MEM_RS1_DATA             : in std_logic_vector(31 downto 0);

        -- ==== REGFILE > ====
        DC_CSR_WE               : out std_logic;
        DC_CSR_DOUT             : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of lagarisc_csr is
    constant C_CSR_RW_SIZE : integer := 9;

    type csr_regfile_t is array(C_CSR_RW_SIZE downto 1) of std_logic_vector(31 downto 0);
    signal csr_regfile : csr_regfile_t;

    signal csr_reg_index : integer range C_CSR_RW_SIZE downto 0;
    signal csr_async_rdata : std_logic_vector(31 downto 0);
    signal csr_async_wdata : std_logic_vector(31 downto 0);

begin

    DC_CSR_DOUT     <= csr_async_rdata;


    P_ASYNC_REG_INDEX: process (MEM_CSR_ID)
    begin
        csr_reg_index <= 0; -- Unknown ID
        case MEM_CSR_ID is
            when CSR_MSTATUS    => csr_reg_index <= 1;
            when CSR_MISA       => csr_reg_index <= 2;
            when CSR_MIE        => csr_reg_index <= 3;
            when CSR_MTVEC      => csr_reg_index <= 4;
            when CSR_MSCRATCH   => csr_reg_index <= 5;
            when CSR_MEPC       => csr_reg_index <= 6;
            when CSR_MCAUSE     => csr_reg_index <= 7;
            when CSR_MTVAL      => csr_reg_index <= 8;
            when CSR_MIP        => csr_reg_index <= 9;
            when others => null;
        end case;

    end process;

    P_ASYNC_REG_RDATA: process (MEM_CSR_ID, csr_reg_index, csr_regfile)
    begin
        DC_CSR_WE <= '1';
        case MEM_CSR_ID is
            -------------------------------------------
            -- Read-Only CSR
            -------------------------------------------
            when CSR_MVENDORID =>
                csr_async_rdata <= CSR_MVENDORID_VALUE;
            when CSR_MARCHID =>
                csr_async_rdata <= CSR_MARCHID_VALUE;
            when CSR_MIMPID =>
                csr_async_rdata <= CSR_MIMPID_VALUE;
            when CSR_MHARTID =>
                csr_async_rdata <= CSR_MHARTID_VALUE;
            -------------------------------------------
            -- Read-Write CSR
            -------------------------------------------
            when others =>
                if csr_reg_index = 0 then
                    -- Unknown ID
                    DC_CSR_WE <= '0'; -- Invalidate write
                    csr_async_rdata <= (others => '0');
                else
                    csr_async_rdata <= csr_regfile(csr_reg_index);
                end if;
        end case;
    end process;

    P_ASYNC_REG_WDATA: process (MEM_CSR_OPCODE, MEM_RS1_DATA, csr_async_rdata)
    begin
        case MEM_CSR_OPCODE is
            when CSR_OPCODE_WRITE =>
                csr_async_wdata <= MEM_RS1_DATA;
            when CSR_OPCODE_SET =>
                csr_async_wdata <= MEM_RS1_DATA or csr_async_rdata;
            when CSR_OPCODE_CLEAR =>
                csr_async_wdata <= (not MEM_RS1_DATA) and csr_async_rdata;
            when others => -- READ
                csr_async_wdata <= csr_async_rdata;
        end case;
    end process;

    P_CSR_REGFILE: process (clk)
    begin
        if rising_edge(clk) then
            if RST = '1' then
                csr_regfile <= (others => (others => '0'));
            else
                if csr_reg_index /= 0 then
                    -- Update CSR for Write/Clear/Set operations
                    if MEM_CSR_OPCODE /= CSR_OPCODE_READ then
                        csr_regfile(csr_reg_index)  <= csr_async_wdata;
                    end if;
                end if;
            end if;
        end if;
    end process P_CSR_REGFILE;
end architecture;