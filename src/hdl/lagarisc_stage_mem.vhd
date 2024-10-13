library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_mem is
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        -- ==== Control & command ====
        STALL                   : in std_logic;
        FLUSH                   : in std_logic;
        FLUSH_ACK               : out std_logic; -- Acknowledge flush (defered flush)

        EXEC_OUT_VALID          : in std_logic;
        MEM_IN_READY            : out std_logic;
        MEM_OUT_VALID           : out std_logic;
        -- WB stage is always read

        -- ==== > EXEC ====
        -- PC
        EXEC_PROGRAM_COUNTER    : in std_logic_vector(31 downto 0);
        EXEC_PC_TAKEN           : in std_logic_vector(31 downto 0);
        EXEC_PC_NOT_TAKEN       : in std_logic_vector(31 downto 0); -- PC + 4
        EXEC_BRANCH_OP          : in branch_op_t;
        -- INST
        EXEC_INST_F3            : in std_logic_vector(2 downto 0);
        -- RSX
        EXEC_RS2_ID             : in std_logic_vector(4 downto 0);
        EXEC_RS2_DATA           : in std_logic_vector(31 downto 0);
        -- RD
        EXEC_RD_ID              : in std_logic_vector(4 downto 0);
        EXEC_RD_WE              : in std_logic;
        -- ALU
        EXEC_ALU_RESULT         : in std_logic_vector(31 downto 0);
        -- LSU
        EXEC_LSU_EN             : in std_logic;
        EXEC_LSU_WE             : in std_logic;
        -- CSR
        EXEC_CSR_ID             : in std_logic_vector(11 downto 0);
        EXEC_CSR_OPCODE         : in csr_opcode_t;
        -- WB MUX
        EXEC_WB_MUX             : in mux_wb_src_t;

        -- ==== WB > ====
        -- PC
        WB_PROGRAM_COUNTER      : out std_logic_vector(31 downto 0);
        -- RD
        WB_RD_ID                : out std_logic_vector(4 downto 0);
        WB_RD_WE                : out std_logic;
        WB_RD_DATA              : out std_logic_vector(31 downto 0);
        -- CSR
        WB_CSR_ID               : out std_logic_vector(11 downto 0);
        WB_CSR_OPCODE           : out csr_opcode_t;
        -- WB MUX
        WB_WB_MUX               : out mux_wb_src_t;

        -- ==== > WB ====
        WB_FWD_RD_ID            : in std_logic_vector(4 downto 0);
        WB_FWD_RD_DATA          : in std_logic_vector(31 downto 0);
        WB_FWD_RD_FWDABLE       : in std_logic;
        WB_FWD_RD_VALID         : in std_logic;

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

    -- Controls & cmds
    signal flush_ack_int        : std_logic;
    signal mem_in_ready_int     : std_logic;
    signal lsu_in_ready_int     : std_logic;
    signal lsu_out_valid_int    : std_logic;
    signal in_handshake_reg     : std_logic;

    signal mem_out_valid_int    : std_logic;
    signal exec_wb_mux_reg      : mux_wb_src_t;

    -- Forwarding
    signal fwd_rs2_data         : std_logic_vector(31 downto 0);
    signal fwd_rs2_available    : std_logic;

    -- Data out
    signal wb_alu_result    : std_logic_vector(31 downto 0);
    signal wb_lsu_dout      : std_logic_vector(31 downto 0);

begin

    -- Controls & cmds
    mem_in_ready_int    <= lsu_in_ready_int and         -- Memory is ready when LSU is ready
                                (not STALL) and         -- Stage must not be stalled by supervisor
                                fwd_rs2_available;      -- RS2 must be available in case of a forwarding

    mem_out_valid_int   <= lsu_out_valid_int when exec_wb_mux_reg = MUX_WB_SRC_LSU else in_handshake_reg; -- when mem_target = MEM_TARGET_FWD

    -- Outputs
    FLUSH_ACK           <= flush_ack_int;
    MEM_IN_READY        <= mem_in_ready_int;
    MEM_OUT_VALID       <= mem_out_valid_int;
    WB_WB_MUX           <= exec_wb_mux_reg;
    WB_RD_DATA          <= wb_lsu_dout       when exec_wb_mux_reg = MUX_WB_SRC_LSU else wb_alu_result;

    inst_lsu : lagarisc_lsu
        port map(
            CLK  => CLK,
            RST  => RST,

            -- ==== Control & command ====
            FLUSH                   => FLUSH,
            FLUSH_ACK               => flush_ack_int, -- Acknowledge flush (defered flush)

            EXEC_OUT_VALID          => EXEC_OUT_VALID,
            LSU_IN_READY            => lsu_in_ready_int,
            MEM_IN_READY            => mem_in_ready_int,
            LSU_OUT_VALID           => lsu_out_valid_int, -- Asserted when transaction (R/W) completed

            -- ==== LSU instructions ====
            -- INST
            EXEC_INST_F3            => EXEC_INST_F3,    -- Used for byte/half/word transations
            -- LSU
            EXEC_LSU_ADDR           => EXEC_ALU_RESULT, -- Memory address is computed from ALU
            EXEC_LSU_DIN            => fwd_rs2_data,    -- RS2 is used as data in.
            EXEC_LSU_EN             => EXEC_LSU_EN,
            EXEC_LSU_WE             => EXEC_LSU_WE,

            -- ==== WB > ====
            WB_LSU_DOUT             => wb_lsu_dout,

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

    -------------------------------------
    -- Forwarding process
    -- Use result from upper stages during data hazards
    -------------------------------------
    P_ASYNC_FORWARDING_UNIT : process (
        EXEC_RS2_ID,
        EXEC_RS2_DATA,
        WB_FWD_RD_ID,
        WB_FWD_RD_DATA,
        WB_FWD_RD_FWDABLE,
        WB_FWD_RD_VALID)
    begin
        fwd_rs2_available   <= '1';
        fwd_rs2_data        <= EXEC_RS2_DATA;

        if (unsigned(EXEC_RS2_ID) /= 0) then
            if(EXEC_RS2_ID = WB_FWD_RD_ID) and (WB_FWD_RD_FWDABLE = '1') then
                -- RS2 : Use data from write back stage
                fwd_rs2_data        <= WB_FWD_RD_DATA;
                fwd_rs2_available   <= WB_FWD_RD_VALID; -- Mem must wait upper stages to access to RS data
            end if;
        end if;
    end process;


    process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                -- Internal status
                in_handshake_reg <= '0';

                -- PC
                SUP_BRANCH_TAKEN        <= '0';
                SUP_PC_TAKEN            <= (others => '-');
                WB_PROGRAM_COUNTER      <= (others => '-');
                -- RD
                WB_RD_ID                <= (others => '-');
                WB_RD_WE                <= '0';
                -- ALU
                wb_alu_result           <= (others => '-');
                -- CSR
                WB_CSR_ID               <= (others => '-');
                WB_CSR_OPCODE           <= CSR_OPCODE_READ;
                -- WB MUX
                exec_wb_mux_reg         <= MUX_WB_SRC_ALU;

            else

                if STALL = '1' then
                    -- Memory stage stall can be required by the supervision
                    -- when fetch stage is not ready and a branch must be taken
                    -- Stall status will be released when fetch stage will
                    -- process the current branching request.
                    null;
                else
                    in_handshake_reg <= '0';

                    if (mem_out_valid_int = '1') then
                        -- After aknowledged by the next stage, RD data is no more
                        -- accessible for forwarding.
                        WB_RD_ID <= (others => '0');
                        WB_RD_WE <= '0';
                    end if;

                    if (mem_in_ready_int = '1') and (EXEC_OUT_VALID = '1') then
                        in_handshake_reg <= '1';

                        -------------------------------------------------
                        -- Register forwarding
                        -------------------------------------------------
                        -- PC
                        WB_PROGRAM_COUNTER      <= EXEC_PROGRAM_COUNTER;
                        -- RD
                        WB_RD_ID                <= EXEC_RD_ID;
                        WB_RD_WE                <= EXEC_RD_WE;          -- Note : RD_WE is not used by WB stage when WB_MUX = MUX_WB_SRC_MEM
                        -- ALU
                        wb_alu_result           <= EXEC_ALU_RESULT;
                        -- CSR
                        WB_CSR_ID               <= EXEC_CSR_ID;
                        WB_CSR_OPCODE           <= EXEC_CSR_OPCODE;
                        -- WB MUX
                        exec_wb_mux_reg         <= EXEC_WB_MUX;

                        -------------------------------------------------
                        -- PC : Branch evaluation
                        -------------------------------------------------
                        SUP_PC_TAKEN            <= EXEC_PC_TAKEN;

                        case EXEC_BRANCH_OP is
                            when BRANCH_OP_COND =>
                                -- Branch is taken when alu result is '1'
                                SUP_BRANCH_TAKEN <= EXEC_ALU_RESULT(0);
                            when BRANCH_OP_UNCOND =>
                                -- Always taken
                                SUP_BRANCH_TAKEN <= '1';
                            when others => -- BRANCH_NOP
                                -- PC += 4
                                SUP_BRANCH_TAKEN <= '0';
                        end case;
                    else
                        SUP_BRANCH_TAKEN    <= '0';
                        WB_CSR_OPCODE       <= CSR_OPCODE_READ;
                    end if;
                end if;

                -- When flush acknowledged (for defered ack)
                if FLUSH = '1' and flush_ack_int = '1' then
                    -- Clear LSU selection => force validitiy to '0'
                    exec_wb_mux_reg     <= MUX_WB_SRC_ALU;
                    in_handshake_reg    <= '0';

                    SUP_BRANCH_TAKEN    <= '0';             -- Disable branching
                    WB_RD_ID            <= (others => '0'); -- Disable forwarding
                    WB_RD_WE            <= '0';             -- Disable write back
                    WB_CSR_OPCODE       <= CSR_OPCODE_READ; -- Disable CSR write
                end if;

            end if;
        end if;
    end process;
end architecture;