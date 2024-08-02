library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lagarisc;
use lagarisc.pkg_lagarisc.all;

entity lagarisc_stage_exec is
    port (
        CLK                     : in std_logic;
        RST                     : in std_logic;

        -- ==== Control & command ====
        FLUSH                   : in std_logic;
        STALL                   : in std_logic;

        DECODE_OUT_VALID        : in std_logic;
        EXEC_IN_READY           : out std_logic;
        EXEC_OUT_VALID          : out std_logic;
        MEM_IN_READY            : in std_logic;

        -- ==== > FETCH ====
        FETCH_PROGRAM_COUNTER   : in std_logic_vector(31 downto 0);

        -- ==== > DECODE ====
        -- PC
        DC_PROGRAM_COUNTER      : in std_logic_vector(31 downto 0);
        DC_BRANCH_OP            : in branch_op_t;
        DC_BRANCH_IMM           : in std_logic_vector(31 downto 0);
        DC_BRANCH_SRC           : in mux_branch_src_t;
        -- INST
        DC_INST_F3              : in std_logic_vector(2 downto 0);
        DC_INST_F7              : in std_logic_vector(6 downto 0);
        -- RSX
        DC_RS1_ID               : in std_logic_vector(4 downto 0);
        DC_RS2_ID               : in std_logic_vector(4 downto 0);
        DC_RS1_DATA             : in std_logic_vector(31 downto 0);
        DC_RS2_DATA             : in std_logic_vector(31 downto 0);
        -- RD
        DC_RD_ID                : in std_logic_vector(4 downto 0);
        DC_RD_WE                : in std_logic;
        -- ALU
        DC_ALU_OPC              : in alu_opcode_t;
        DC_ALU_IMM              : in std_logic_vector(31 downto 0);
        DC_ALU_SHAMT            : in std_logic_vector(4 downto 0);
        DC_ALU_OP1_MUX          : in mux_alu_op1_t;
        DC_ALU_OP2_MUX          : in mux_alu_op2_t;
        -- MEM
        DC_MEM_EN               : in std_logic;
        DC_MEM_WE               : in std_logic;
        -- CSR
        DC_CSR_ID               : in std_logic_vector(11 downto 0);
        DC_CSR_OPCODE           : in csr_opcode_t;
        -- WB MUX
        DC_WB_MUX               : in mux_wb_src_t;

        -- ==== MEM > ====
        -- PC
        MEM_PC_TAKEN            : out std_logic_vector(31 downto 0);
        MEM_PC_NOT_TAKEN        : out std_logic_vector(31 downto 0); -- PC + 4
        MEM_BRANCH_OP           : out branch_op_t;
        -- INST
        MEM_INST_F3             : out std_logic_vector(2 downto 0);
        -- RD
        MEM_RD_ID               : out std_logic_vector(4 downto 0);
        MEM_RD_WE               : out std_logic;
        -- FWD RD
        MEM_FWD_RD_ID           : in std_logic_vector(4 downto 0);
        MEM_FWD_RD_DATA         : in std_logic_vector(31 downto 0);
        MEM_FWD_RD_WE           : in std_logic;
        -- ALU
        MEM_ALU_RESULT          : out std_logic_vector(31 downto 0);
        -- MEM
        MEM_MEM_DIN             : out std_logic_vector(31 downto 0);
        MEM_MEM_EN              : out std_logic;
        MEM_MEM_WE              : out std_logic;
        -- CSR
        MEM_CSR_ID              : out std_logic_vector(11 downto 0);
        MEM_CSR_OPCODE          : out csr_opcode_t;
        -- WB MUX
        MEM_WB_MUX              : out mux_wb_src_t;

        -- ==== > WB ====
        WB_FWD_RD_ID            : in std_logic_vector(4 downto 0);
        WB_FWD_RD_DATA          : in std_logic_vector(31 downto 0);
        WB_FWD_RD_WE            : in std_logic
    );
end entity;

architecture rtl of lagarisc_stage_exec is
    signal exec_in_ready_int : std_logic;
    signal alu_in_ready : std_logic;
    signal fwd_rs1_data : std_logic_vector(31 downto 0);
    signal fwd_rs2_data : std_logic_vector(31 downto 0);
begin
    exec_in_ready_int <= alu_in_ready;
    EXEC_IN_READY <= exec_in_ready_int;

    inst_alu : lagarisc_alu
        port map(
            CLK                     => CLK,
            RST                     => RST,
            -- ==== Control & command ====
            FLUSH                   => FLUSH,
            STALL                   => STALL,

            DECODE_OUT_VALID        => DECODE_OUT_VALID,
            EXEC_IN_READY           => exec_in_ready_int,
            ALU_IN_READY            => alu_in_ready,
            ALU_OUT_VALID           => EXEC_OUT_VALID,
            MEM_IN_READY            => MEM_IN_READY,

            -- ==== > DECODE ====
            -- PC
            DC_PROGRAM_COUNTER      => DC_PROGRAM_COUNTER,
            -- RSX
            DC_RS1_DATA             => fwd_rs1_data,
            DC_RS2_DATA             => fwd_rs2_data,
            -- ALU
            DC_ALU_OPC              => DC_ALU_OPC,
            DC_ALU_IMM              => DC_ALU_IMM,
            DC_ALU_SHAMT            => DC_ALU_SHAMT,
            DC_ALU_OP1_MUX          => DC_ALU_OP1_MUX,
            DC_ALU_OP2_MUX          => DC_ALU_OP2_MUX,
            -- ==== MEM > ====
            MEM_ALU_RESULT          => MEM_ALU_RESULT
        );

    -------------------------------------
    -- Forwarding process
    -- Use result from upper stages during data hazards
    -------------------------------------
    P_FORWARDING_UNIT : process (
        DC_RS1_DATA,
        DC_RS2_DATA,
        DC_RS1_ID,
        DC_RS2_ID,
        MEM_FWD_RD_ID,
        MEM_FWD_RD_DATA,
        MEM_FWD_RD_WE,
        WB_FWD_RD_ID,
        WB_FWD_RD_DATA,
        WB_FWD_RD_WE)
    begin
        fwd_rs1_data <= DC_RS1_DATA;
        fwd_rs2_data <= DC_RS2_DATA;

        -- RS1
        if (unsigned(DC_RS1_ID) /= 0) and (MEM_FWD_RD_WE = '1') then
            -- Per priority
            if(DC_RS1_ID = MEM_FWD_RD_ID) then
                -- RS1 : Use data from memory stage
                fwd_rs1_data    <= MEM_FWD_RD_DATA;
            elsif(DC_RS1_ID = WB_FWD_RD_ID) then
                -- RS1 : Use data from write-back stage
                fwd_rs1_data    <= WB_FWD_RD_DATA;
            end if;
        end if;

        -- RS2
        if (unsigned(DC_RS2_ID) /= 0) and (WB_FWD_RD_WE = '1') then
            -- Per priority
            if(DC_RS2_ID = MEM_FWD_RD_ID) then
                -- RS2 : Use data from memory stage
                fwd_rs2_data    <= MEM_FWD_RD_DATA;
            elsif(DC_RS2_ID = WB_FWD_RD_ID) then
                -- RS2 : Use data from write-back stage
                fwd_rs2_data    <= WB_FWD_RD_DATA;
            end if;
        end if;
    end process;

    ----------------------------------------
    -- Branching process
    -- Compute next PC for branching operations
    ----------------------------------------
    P_BRANCH : process (CLK)
        variable op1 : std_logic_vector(31 downto 0);
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                MEM_PC_TAKEN       <= (others => '-');
                MEM_PC_NOT_TAKEN   <= (others => '-');
            else
                if STALL = '1' then
                    null;
                elsif (alu_in_ready = '1') and (DECODE_OUT_VALID = '1') then
                    ---------------------------------------------
                    -- Compute every PC possible (taken/not taken)
                    ---------------------------------------------
                    -- Branch not taken  : PC = PC + 4
                    MEM_PC_NOT_TAKEN <= FETCH_PROGRAM_COUNTER;

                    -- Branch taken :
                    if DC_BRANCH_SRC = MUX_BRANCH_SRC_PC then
                        -- PC = PC + IMM
                        op1 := DC_PROGRAM_COUNTER;
                    else  -- DC_BRANCH_SRC = MUX_BRANCH_SRC_RS1
                        -- PC = RS1 + IMM
                        op1 := fwd_rs1_data;
                    end if;
                    MEM_PC_TAKEN <= std_logic_vector(unsigned(op1) + unsigned(DC_BRANCH_IMM));
                end if;
            end if;
        end if;
    end process;

    P_PIPELINE_REG : process (CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                -- PC
                MEM_BRANCH_OP   <= BRANCH_NOP;
                -- INST
                MEM_INST_F3     <= (others => '-');
                -- RD
                MEM_RD_ID       <= (others => '-');
                MEM_RD_WE       <= '0';
                -- MEM
                MEM_MEM_DIN     <= (others => '-');
                MEM_MEM_EN      <= '0';
                MEM_MEM_WE      <= '0';
                -- CSR
                MEM_CSR_ID      <= (others => '-');
                MEM_CSR_OPCODE  <= CSR_OPCODE_READ;
                -- WB MUX
                MEM_WB_MUX      <= MUX_WB_SRC_ALU;
            else

                if STALL = '1' then
                    null;
                elsif (exec_in_ready_int = '1') and (DECODE_OUT_VALID = '1')  then
                    -- PC
                    MEM_BRANCH_OP   <= DC_BRANCH_OP;
                    -- INST
                    MEM_INST_F3     <= DC_INST_F3;
                    -- RD
                    MEM_RD_ID       <= DC_RD_ID;
                    MEM_RD_WE       <= DC_RD_WE;
                    -- MEM
                    MEM_MEM_DIN     <= DC_RS2_DATA;
                    MEM_MEM_EN      <= DC_MEM_EN;
                    MEM_MEM_WE      <= DC_MEM_WE;
                    -- CSR
                    MEM_CSR_ID      <= DC_CSR_ID;
                    MEM_CSR_OPCODE  <= DC_CSR_OPCODE;
                    -- WB MUX
                    MEM_WB_MUX      <= DC_WB_MUX;
                end if;

                if FLUSH = '1' then
                    MEM_RD_WE       <= '0';
                    MEM_MEM_EN      <= '0';
                    MEM_MEM_WE      <= '0';
                    MEM_CSR_OPCODE  <= CSR_OPCODE_READ;
                end if;
            end if;
        end if;
    end process;
end architecture;