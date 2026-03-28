----------------------------------------------------------------------------------
-- Instruction Decoder -- translates the 18-bit instruction word into
-- control signals for the datapath, ALU, memory, IO, and branching.
--
-- Purely combinational. The 6-bit opcode (bits 17..12) selects the
-- operation; bits 11..8 are always the destination register sX,
-- bits 7..4 / 7..0 carry the source register sY or an 8-bit immediate.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.alu_pkg.all;
use work.controlunit_pkg.all;
use work.common.all;

entity instruction_decoder is
    Port (
        instruction : in  std_logic_vector(17 downto 0); -- 18-bit instruction straight from ROM
        alu_op      : out alu_op_t;                      -- decoded ALU opcode (from alu_pkg)
        reg_write   : out std_logic;                     -- enables destination register write
        mem_read    : out std_logic;                     -- high for scratch-pad/data-memory reads
        mem_write   : out std_logic;                     -- high for scratch-pad/data-memory writes

        -- Dedicated IO interface (memory-mapped IO is split out here)
        io_rd       : out std_logic;                     -- high for IO reads (INPUT)
        io_wr       : out std_logic;                     -- high for IO writes (OUTPUT)
        imm8        : out ro2_word;                      -- immediate value (only valid when alu_src='1')
        alu_src     : out std_logic;                     -- selects ALU B source (0=register, 1=imm)
        reg_dst     : out std_logic_vector(3 downto 0);  -- destination register index
        jump_cond   : out jump_cond_t;                    -- branch condition passed to branch logic
        reg_src_b   : out std_logic_vector(3 downto 0);  -- source register index B (SY)
        flag_write  : out std_logic;                     -- '1' when instruction updates carry/zero flags
        reads_reg_a : out std_logic;                     -- '1' when instruction reads register A (sX)
        reads_reg_b : out std_logic                      -- '1' when instruction reads register B (sY)
    );
end instruction_decoder;

architecture rtl of instruction_decoder is
    subtype opcode_t is std_logic_vector(5 downto 0);

    ----------------------------------------------------------------
    -- Opcode constants -- encoding matches the RO2 ISA spec
    ----------------------------------------------------------------
    constant OPC_NOP         : opcode_t := "000000";

    -- arithmetic
    constant OPC_ADD_REG     : opcode_t := "000010";
    constant OPC_ADD_IMM     : opcode_t := "000011";
    constant OPC_ADDCY_REG   : opcode_t := "000100";
    constant OPC_ADDCY_IMM   : opcode_t := "000101";
    constant OPC_SUB_REG     : opcode_t := "000110";
    constant OPC_SUB_IMM     : opcode_t := "000111";
    constant OPC_SUBCY_REG   : opcode_t := "001000";
    constant OPC_SUBCY_IMM   : opcode_t := "001001";

    -- logic
    constant OPC_AND_REG     : opcode_t := "001010";
    constant OPC_AND_IMM     : opcode_t := "001011";
    constant OPC_OR_REG      : opcode_t := "001100";
    constant OPC_OR_IMM      : opcode_t := "001101";
    constant OPC_XOR_REG     : opcode_t := "001110";
    constant OPC_XOR_IMM     : opcode_t := "001111";

    -- compare / test (flag-only, no write-back)
    constant OPC_COMPARE_REG   : opcode_t := "010000";
    constant OPC_COMPARE_IMM   : opcode_t := "010001";
    constant OPC_TEST_REG      : opcode_t := "010010";
    constant OPC_TEST_IMM      : opcode_t := "010011";
    constant OPC_COMPARECY_REG : opcode_t := "011110";
    constant OPC_COMPARECY_IMM : opcode_t := "011111";
    constant OPC_TESTCY_REG    : opcode_t := "101100";
    constant OPC_TESTCY_IMM    : opcode_t := "101101";

    -- register load
    constant OPC_LOAD_REG    : opcode_t := "010100";
    constant OPC_LOAD_IMM    : opcode_t := "010101";

    -- IO
    constant OPC_INPUT_REG   : opcode_t := "010110";
    constant OPC_INPUT_IMM   : opcode_t := "010111";
    constant OPC_OUTPUT_REG  : opcode_t := "011000";
    constant OPC_OUTPUT_IMM  : opcode_t := "011001";

    -- scratchpad memory
    constant OPC_FETCH_REG   : opcode_t := "011010";
    constant OPC_FETCH_IMM   : opcode_t := "011011";
    constant OPC_STORE_REG   : opcode_t := "011100";
    constant OPC_STORE_IMM   : opcode_t := "011101";

    -- shifts / rotates (single-operand, operate on sX only)
    constant OPC_RL          : opcode_t := "100000";
    constant OPC_RR          : opcode_t := "100010";
    constant OPC_SL0         : opcode_t := "100011";
    constant OPC_SL1         : opcode_t := "100100";
    constant OPC_SLA         : opcode_t := "100101";
    constant OPC_SLX         : opcode_t := "100110";
    constant OPC_SR0         : opcode_t := "100111";
    constant OPC_SR1         : opcode_t := "101000";
    constant OPC_SRA         : opcode_t := "101001";
    constant OPC_SRX         : opcode_t := "101010";

    -- jumps / branches
    constant OPC_JUMP        : opcode_t := "110000";
    constant OPC_JZ          : opcode_t := "110001";
    constant OPC_JNZ         : opcode_t := "110010";
    constant OPC_JC          : opcode_t := "110011";
    constant OPC_JNC         : opcode_t := "110100";
begin
    process(instruction)
        variable opcode : opcode_t := (others => '0');
        variable rd     : std_logic_vector(3 downto 0) := (others => '0');

    begin
        -- slice the instruction into its fields
        opcode := instruction(17 downto 12);
        rd     := instruction(11 downto 8);

        -- safe defaults: everything off, no jump, both register reads assumed
        alu_op    <= ALU_NOP;
        reg_write <= '0';
        mem_read  <= '0';
        mem_write <= '0';
        io_rd     <= '0';
        io_wr     <= '0';
        alu_src   <= '0';
        reg_dst   <= rd;
        jump_cond <= J_NONE;
        reg_src_b <= instruction(7 downto 4);
        imm8      <= (others => '0');
        flag_write <= '0';
        reads_reg_a <= '1';
        reads_reg_b <= '1';

        case opcode is

            -- Arithmetic: sX <= sX op sY  /  sX <= sX op kk
            when OPC_ADD_REG =>
                alu_op <= ALU_ADD;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_ADD_IMM =>
                alu_op <= ALU_ADD;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_ADDCY_REG =>
                alu_op <= ALU_ADDCY;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_ADDCY_IMM =>
                alu_op <= ALU_ADDCY;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_SUB_REG =>
                alu_op <= ALU_SUB;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_SUB_IMM =>
                alu_op <= ALU_SUB;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_SUBCY_REG =>
                alu_op <= ALU_SUBCY;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_SUBCY_IMM =>
                alu_op <= ALU_SUBCY;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            -- Logic: sX <= sX op sY  /  sX <= sX op kk
            when OPC_AND_REG =>
                alu_op <= ALU_AND;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_AND_IMM =>
                alu_op <= ALU_AND;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_OR_REG =>
                alu_op <= ALU_OR;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_OR_IMM =>
                alu_op <= ALU_OR;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_XOR_REG =>
                alu_op <= ALU_XOR;  reg_write <= '1';  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_XOR_IMM =>
                alu_op <= ALU_XOR;  reg_write <= '1';  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            -- Compare / Test -- only update flags, no write-back
            when OPC_COMPARE_REG =>
                alu_op <= ALU_SUB;  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_COMPARE_IMM =>
                alu_op <= ALU_SUB;  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_TEST_REG =>
                alu_op <= ALU_TEST;  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_TEST_IMM =>
                alu_op <= ALU_TEST;  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_COMPARECY_REG =>
                alu_op <= ALU_COMPARECY;  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_COMPARECY_IMM =>
                alu_op <= ALU_COMPARECY;  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_TESTCY_REG =>
                alu_op <= ALU_TESTCY;  flag_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_TESTCY_IMM =>
                alu_op <= ALU_TESTCY;  flag_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            -- LOAD -- move sY or immediate into sX
            when OPC_LOAD_REG =>
                alu_op <= ALU_PASS_B;  reg_write <= '1';
                reads_reg_a <= '0';
                reg_src_b <= instruction(7 downto 4);

            when OPC_LOAD_IMM =>
                alu_op <= ALU_PASS_B;  reg_write <= '1';
                reads_reg_a <= '0';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            -- IO -- INPUT reads from port, OUTPUT writes to port
            -- address_out is wired to B_alu directly, so the ALU is unused.
            when OPC_INPUT_REG =>
                alu_op <= ALU_NOP;  io_rd <= '1';  reg_write <= '1';
                reads_reg_a <= '0';
                reg_src_b <= instruction(7 downto 4);

            when OPC_INPUT_IMM =>
                alu_op <= ALU_NOP;  io_rd <= '1';  reg_write <= '1';
                reads_reg_a <= '0';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_OUTPUT_REG =>
                alu_op <= ALU_NOP;  io_wr <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_OUTPUT_IMM =>
                alu_op <= ALU_NOP;  io_wr <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            -- Scratchpad memory -- FETCH reads, STORE writes
            -- Address comes from sY (reg) or kk (immediate).
            when OPC_FETCH_REG =>
                alu_op <= ALU_NOP;  mem_read <= '1';  reg_write <= '1';
                reads_reg_a <= '0';
                reg_src_b <= instruction(7 downto 4);

            when OPC_FETCH_IMM =>
                alu_op <= ALU_NOP;  mem_read <= '1';  reg_write <= '1';
                reads_reg_a <= '0';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            when OPC_STORE_REG =>
                alu_op <= ALU_NOP;  mem_write <= '1';
                reg_src_b <= instruction(7 downto 4);

            when OPC_STORE_IMM =>
                alu_op <= ALU_NOP;  mem_write <= '1';
                alu_src <= '1';  reads_reg_b <= '0';
                imm8 <= instruction(7 downto 0);

            -- Shifts / Rotates -- single-operand, only sX involved
            when OPC_RL =>
                alu_op <= ALU_RL;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_RR =>
                alu_op <= ALU_RR;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SL0 =>
                alu_op <= ALU_SL0;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SL1 =>
                alu_op <= ALU_SL1;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SLA =>
                alu_op <= ALU_SLA;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SLX =>
                alu_op <= ALU_SLX;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SR0 =>
                alu_op <= ALU_SR0;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SR1 =>
                alu_op <= ALU_SR1;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SRA =>
                alu_op <= ALU_SRA;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            when OPC_SRX =>
                alu_op <= ALU_SRX;  reg_write <= '1';  flag_write <= '1';
                reads_reg_b <= '0';

            -- Jumps / Branches -- no register access, just set
            -- the jump condition for branch_logic to evaluate.
            when OPC_JUMP =>
                jump_cond <= J_UNCOND;
                reads_reg_a <= '0';  reads_reg_b <= '0';

            when OPC_JZ =>
                jump_cond <= J_Z;
                reads_reg_a <= '0';  reads_reg_b <= '0';

            when OPC_JNZ =>
                jump_cond <= J_NZ;
                reads_reg_a <= '0';  reads_reg_b <= '0';

            when OPC_JC =>
                jump_cond <= J_C;
                reads_reg_a <= '0';  reads_reg_b <= '0';

            when OPC_JNC =>
                jump_cond <= J_NC;
                reads_reg_a <= '0';  reads_reg_b <= '0';

            -- NOP / unknown -- do nothing
            when OPC_NOP =>
                alu_op <= ALU_NOP;
                reads_reg_a <= '0';  reads_reg_b <= '0';

            when others =>
                null;
        end case;
    end process;
end rtl;
