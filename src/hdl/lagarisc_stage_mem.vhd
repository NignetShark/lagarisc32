library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_mem is
    generic (
        G_BOOT_ADDR     : std_logic_vector(31 downto 0) := x"00000000"
    );
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        -- ==== Control & command ====
        STALL                   : in std_logic;
        FLUSH                   : in std_logic;
        FLUSH_ACK               : out std_logic; -- Acknowledge flush (defered flush)

        EXEC_OUT_VALID          : in std_logic;
        MEM_IN_READY            : out std_logic;
        -- WB stage is always read
        -- Mem output is always valid (at least control signals)

        -- ==== > EXEC ====
        -- PC
        EXEC_PC_TAKEN           : in std_logic_vector(31 downto 0);
        EXEC_PC_NOT_TAKEN       : in std_logic_vector(31 downto 0); -- PC + 4
        EXEC_BRANCH_OP          : in branch_op_t;
        -- INST
        EXEC_INST_F3            : in std_logic_vector(2 downto 0);
        -- RD
        EXEC_RD_ID              : in std_logic_vector(4 downto 0);
        EXEC_RD_WE              : in std_logic;
        -- ALU
        EXEC_ALU_RESULT         : in std_logic_vector(31 downto 0);
        -- MEM
        EXEC_MEM_DIN            : in std_logic_vector(31 downto 0);
        EXEC_MEM_EN             : in std_logic;
        EXEC_MEM_WE             : in std_logic;
        -- CSR
        EXEC_CSR_ID             : in std_logic_vector(11 downto 0);
        EXEC_CSR_OPCODE         : in csr_opcode_t;
        -- WB MUX
        EXEC_WB_MUX             : in mux_wb_src_t;

        -- ==== WB > ====
        -- PC
        WB_PC_NOT_TAKEN         : out std_logic_vector(31 downto 0);
        -- RD
        WB_RD_ID                : out std_logic_vector(4 downto 0);
        WB_RD_WE                : out std_logic;
        -- ALU
        WB_ALU_RESULT           : out std_logic_vector(31 downto 0);
        -- MEM
        WB_MEM_DOUT             : out std_logic_vector(31 downto 0);
        WB_MEM_WE               : out std_logic;
        -- CSR
        WB_CSR_ID               : out std_logic_vector(11 downto 0);
        WB_CSR_OPCODE           : out csr_opcode_t;
        -- WB MUX
        WB_WB_MUX               : out mux_wb_src_t;

        -- ==== SUPERVISOR > ====
        -- PC
        SUP_BRANCH_TAKEN        : out std_logic;
        SUP_PC_TAKEN            : out std_logic_vector(31 downto 0);

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

architecture rtl of lagarisc_stage_mem is
    signal mem_in_ready_int : std_logic;
    signal lsu_in_ready_int : std_logic;
    signal lsu_out_valid_int : std_logic;

begin
    mem_in_ready_int <= lsu_in_ready_int and (not STALL);
    MEM_IN_READY <= mem_in_ready_int;

    inst_lsu : lagarisc_lsu
        port map(
            CLK  => CLK,
            RST  => RST,

            -- ==== Control & command ====
            FLUSH                   => FLUSH,
            FLUSH_ACK               => FLUSH_ACK, -- Acknowledge flush (defered flush)

            EXEC_OUT_VALID          => EXEC_OUT_VALID,
            LSU_IN_READY            => lsu_in_ready_int,
            MEM_IN_READY            => mem_in_ready_int,
            LSU_OUT_VALID           => lsu_out_valid_int,

            -- INST
            EXEC_INST_F3            => EXEC_INST_F3,
            -- MEM
            EXEC_MEM_ADDR           => EXEC_ALU_RESULT, -- Memory address is computed from ALU
            EXEC_MEM_DIN            => EXEC_MEM_DIN,
            EXEC_MEM_EN             => EXEC_MEM_EN,
            EXEC_MEM_WE             => EXEC_MEM_WE,

            -- ==== WB > ====
            WB_MEM_DOUT             => WB_MEM_DOUT,
            WB_MEM_WE               => WB_MEM_WE,

            -- ==== > AXI4L interface > ====
            -- write access
            AXI_AWVALID             => AXI_AWVALID,
            AXI_AWREADY             => AXI_AWREADY,
            AXI_AWADDR              => AXI_AWADDR,
            AXI_AWPROT              => AXI_AWPROT,
            AXI_WVALID              => AXI_WVALID,
            AXI_WREADY              => AXI_WREADY,
            AXI_WDATA               => AXI_WDATA,
            AXI_WSTRB               => AXI_WSTRB,
            AXI_BVALID              => AXI_BVALID,
            AXI_BREADY              => AXI_BREADY,
            AXI_BRESP               => AXI_BRESP,
            --read access
            AXI_ARVALID             => AXI_ARVALID,
            AXI_ARREADY             => AXI_ARREADY,
            AXI_ARADDR              => AXI_ARADDR,
            AXI_ARPROT              => AXI_ARPROT,
            AXI_RVALID              => AXI_RVALID,
            AXI_RREADY              => AXI_RREADY,
            AXI_RDATA               => AXI_RDATA,
            AXI_RESP                => AXI_RESP
        );

    process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                -- PC
                SUP_BRANCH_TAKEN        <= '0';
                SUP_PC_TAKEN            <= (others => '-');
                WB_PC_NOT_TAKEN         <= (others => '-');
                -- RD
                WB_RD_ID                <= (others => '-');
                WB_RD_WE                <= '0';
                -- ALU
                WB_ALU_RESULT           <= (others => '-');
                -- CSR
                WB_CSR_ID               <= (others => '-');
                WB_CSR_OPCODE           <= CSR_OPCODE_READ;
                -- WB MUX
                WB_WB_MUX               <= MUX_WB_SRC_ALU;

            else

                if STALL = '1' then
                    -- Stalling memory stage can be required by the supervision
                    -- when fetch stage is not ready and a branch must be taken
                    null;
                elsif (mem_in_ready_int = '1') and (EXEC_OUT_VALID = '1') then
                    -------------------------------------------------
                    -- Register forwarding
                    -------------------------------------------------
                    -- RD
                    WB_RD_ID                <= EXEC_RD_ID;
                    WB_RD_WE                <= EXEC_RD_WE;          -- Note : RD_WE is not used by WB stage when WB_MUX = MUX_WB_SRC_MEM
                    -- ALU
                    WB_ALU_RESULT           <= EXEC_ALU_RESULT;
                    -- CSR
                    WB_CSR_ID               <= EXEC_CSR_ID;
                    WB_CSR_OPCODE           <= EXEC_CSR_OPCODE;
                    -- WB MUX
                    WB_WB_MUX               <= EXEC_WB_MUX;

                    -------------------------------------------------
                    -- PC : Branch evaluation
                    -------------------------------------------------
                    WB_PC_NOT_TAKEN         <= EXEC_PC_NOT_TAKEN;
                    SUP_PC_TAKEN            <= EXEC_PC_TAKEN;

                    case EXEC_BRANCH_OP is
                        when BRANCH_OP_COND =>
                            SUP_BRANCH_TAKEN <= EXEC_ALU_RESULT(0);
                        when BRANCH_OP_UNCOND =>
                            SUP_BRANCH_TAKEN <= '1';
                        when others => -- BRANCH_NOP
                            SUP_BRANCH_TAKEN <= '0';
                    end case;

                else
                    SUP_BRANCH_TAKEN    <= '0';
                    --WB_RD_WE            <= '0';
                    WB_CSR_OPCODE       <= CSR_OPCODE_READ;
                end if;

                if FLUSH = '1' then
                    SUP_BRANCH_TAKEN    <= '0';
                    WB_RD_ID            <= (others => '0'); -- Prevent forwarding
                    --WB_RD_WE            <= '0';
                    WB_CSR_OPCODE       <= CSR_OPCODE_READ;
                end if;

            end if;
        end if;
    end process;
end architecture;