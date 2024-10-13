library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lagarisc_fwd_unit is
    port (
        -- ==== > DECODE ====
        DECODE_OUT_VALID    : in std_logic;
        DC_RS1_ID           : in std_logic_vector(4 downto 0);
        DC_RS2_ID           : in std_logic_vector(4 downto 0);
        DC_RS1_DATA         : in std_logic_vector(31 downto 0);
        DC_RS2_DATA         : in std_logic_vector(31 downto 0);

        -- ==== > EXEC ====
        EXEC_OUT_VALID      : in std_logic;
        EXEC_RD_ID          : in std_logic_vector(4 downto 0);
        EXEC_RD_WE          : in std_logic;
        EXEC_RD_DATA        : in std_logic_vector(31 downto 0);
        EXEC_LSU_EN         : in std_logic;
        EXEC_LSU_WE         : in std_logic;

        -- ==== > MEM ====
        MEM_OUT_VALID       : in std_logic;
        MEM_RD_ID           : in std_logic_vector(4 downto 0);
        MEM_RD_WE           : in std_logic;
        MEM_RD_DATA         : in std_logic_vector(31 downto 0);

        -- ==== EXEC > ====
        FWD_RS1_DATA        : out std_logic_vector(31 downto 0);
        FWD_RS2_DATA        : out std_logic_vector(31 downto 0);
        FWD_RSX_READY       : out std_logic
    );
end entity;

architecture rtl of lagarisc_fwd_unit is
    signal rs1_available, rs2_available : std_logic;
    signal mem_read : std_logic;
begin
    -- Memory read access
    mem_read <= EXEC_LSU_EN and not EXEC_LSU_WE;

    -- Forwarding validity
    FWD_RSX_READY <= rs1_available and rs2_available;

    process (
        DECODE_OUT_VALID,
        DC_RS1_ID,
        DC_RS2_ID,
        DC_RS1_DATA,
        DC_RS2_DATA,
        EXEC_OUT_VALID,
        EXEC_RD_ID,
        EXEC_RD_WE,
        EXEC_RD_DATA,
        MEM_OUT_VALID,
        MEM_RD_ID,
        MEM_RD_WE,
        MEM_RD_DATA,
        mem_read
    )
    begin
        -- By default no forwarding:
        FWD_RS1_DATA    <= DC_RS1_DATA;
        FWD_RS2_DATA    <= DC_RS2_DATA;
        rs1_available   <= DECODE_OUT_VALID;
        rs2_available   <= DECODE_OUT_VALID;

        -- RS1
        if (unsigned(DC_RS1_ID) /= 0) then
            -- Per priority:

            -- EXEC data hazard
            if(DC_RS1_ID = EXEC_RD_ID) and (EXEC_RD_WE = '1') then
                if mem_read = '1' then
                    -- Forwarding from EXEC is a false path
                    -- since RD data is produce by MEM stage
                    -- => Skip forwarding by stalling EXEC stage
                    -- After which, the forwarded data will be picked
                    -- from memory stage
                    rs1_available <= '0';
                else
                    FWD_RS1_DATA    <= EXEC_RD_DATA;
                    rs1_available   <= EXEC_OUT_VALID;
                end if;

            -- MEM data hazard
            elsif(DC_RS1_ID = MEM_RD_ID) and (MEM_RD_WE = '1')  then
                FWD_RS1_DATA    <= MEM_RD_DATA;
                rs1_available   <= MEM_OUT_VALID;
            end if;
        end if;

        -- RS2
        if (unsigned(DC_RS2_ID) /= 0) then
            -- Per priority:

            -- EXEC data hazard
            if(DC_RS2_ID = EXEC_RD_ID) and (EXEC_RD_WE = '1') then
                if mem_read = '1' then
                    -- Forwarding from EXEC is a false path
                    -- since RD data is produce by MEM stage
                    -- => Skip forwarding by stalling EXEC stage
                    -- After which, the forwarded data will be picked
                    -- from memory stage
                    rs2_available <= '0';
                else
                    FWD_RS2_DATA   <= EXEC_RD_DATA;
                    rs2_available  <= EXEC_OUT_VALID;
                end if;

            -- MEM data hazard
            elsif(DC_RS2_ID = MEM_RD_ID) and (MEM_RD_WE = '1')  then
                -- RS2 : Use data from write-back stage
                FWD_RS2_DATA    <= MEM_RD_DATA;
                rs2_available   <= MEM_OUT_VALID;
            end if;
        end if;

    end process;

end architecture;