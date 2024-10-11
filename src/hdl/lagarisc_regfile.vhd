library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;


entity lagarisc_regfile is
    port (
        CLK     : in std_logic;
        RST     : in std_logic;

        -- From decode stage
        DC_RS1_ID       : in std_logic_vector(4 downto 0);
        DC_RS2_ID       : in std_logic_vector(4 downto 0);

        -- Register file output
        RS1_DATA        : out std_logic_vector(31 downto 0);
        RS2_DATA        : out std_logic_vector(31 downto 0);

        -- From write back stage
        WB_RD_ID       : in std_logic_vector(4 downto 0);
        WB_RD_DATA     : in std_logic_vector(31 downto 0);
        WB_RD_WE       : in std_logic;
        WB_RD_VALID    : in std_logic
    );
end entity;

architecture rtl of lagarisc_regfile is
    constant C_R0 : std_logic_vector(31 downto 0) := (others => '0');

    type regfile_t is array(1 to 31) of std_logic_vector(31 downto 0);
    signal regfile : regfile_t;

    signal valid_we : std_logic;
begin

    valid_we <= WB_RD_WE and WB_RD_VALID;

    process(CLK) is
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                regfile <= (others => (others => '0'));
            else
                -- RS1
                if unsigned(DC_RS1_ID) = 0 then
                    RS1_DATA <= C_R0;
                elsif (valid_we = '1') and (DC_RS1_ID = WB_RD_ID) then -- forwarding RD
                    RS1_DATA <= WB_RD_DATA;
                else
                    RS1_DATA <= regfile(to_integer(unsigned(DC_RS1_ID)));
                end if;

                -- RS2
                if unsigned(DC_RS2_ID) = 0 then
                    RS2_DATA <= C_R0;
                elsif (valid_we = '1') and (DC_RS2_ID = WB_RD_ID) then -- forwarding RD
                    RS2_DATA <= WB_RD_DATA;
                else
                    RS2_DATA <= regfile(to_integer(unsigned(DC_RS2_ID)));
                end if;

                -- RD
                if (valid_we = '1') and (unsigned(WB_RD_ID) /= 0) then
                    regfile(to_integer(unsigned(WB_RD_ID))) <= WB_RD_DATA;
                end if;
            end if;
        end if;
    end process;

end architecture;