----------------------------------------------------------------------------------
-- Testbench for instruction_decoder
--
-- Drives every opcode through the purely combinational decoder and checks
-- that the correct control signal bundle comes out. Uses a record type
-- (ctrl_exp_t) so each assertion covers all outputs at once.
--
-- Helper functions mk_reg / mk_imm / mk_jump build 18-bit instruction
-- words from opcode + operand fields to keep the stimulus readable.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.alu_pkg.all;
use work.controlunit_pkg.all;
use work.common.all;

entity instruction_decoder_tb is
end entity;

architecture sim of instruction_decoder_tb is

    signal instruction : std_logic_vector(17 downto 0) := (others => '0');

    signal alu_op      : alu_op_t;
    signal reg_write   : std_logic;
    signal mem_read    : std_logic;
    signal mem_write   : std_logic;
    signal io_rd       : std_logic;
    signal io_wr       : std_logic;
    signal imm8        : ro2_word;
    signal alu_src     : std_logic;
    signal reg_dst     : std_logic_vector(3 downto 0);
    signal jump_cond   : jump_cond_t;
    signal reg_src_b   : std_logic_vector(3 downto 0);
    signal flag_write  : std_logic;
    signal reads_reg_a : std_logic;
    signal reads_reg_b : std_logic;

    -- local opcode constants (mirrors the ones inside the decoder)
    subtype opcode_t is std_logic_vector(5 downto 0);

    constant OPC_NOP         : opcode_t := "000000";
    constant OPC_ADD_REG     : opcode_t := "000010";
    constant OPC_ADD_IMM     : opcode_t := "000011";
    constant OPC_ADDCY_REG   : opcode_t := "000100";
    constant OPC_ADDCY_IMM   : opcode_t := "000101";
    constant OPC_SUB_REG     : opcode_t := "000110";
    constant OPC_SUB_IMM     : opcode_t := "000111";
    constant OPC_SUBCY_REG   : opcode_t := "001000";
    constant OPC_SUBCY_IMM   : opcode_t := "001001";
    constant OPC_AND_REG     : opcode_t := "001010";
    constant OPC_AND_IMM     : opcode_t := "001011";
    constant OPC_OR_REG      : opcode_t := "001100";
    constant OPC_OR_IMM      : opcode_t := "001101";
    constant OPC_XOR_REG     : opcode_t := "001110";
    constant OPC_XOR_IMM     : opcode_t := "001111";
    constant OPC_COMPARE_REG : opcode_t := "010000";
    constant OPC_COMPARE_IMM : opcode_t := "010001";
    constant OPC_TEST_REG    : opcode_t := "010010";
    constant OPC_TEST_IMM    : opcode_t := "010011";
    constant OPC_COMPARECY_REG : opcode_t := "011110";
    constant OPC_COMPARECY_IMM : opcode_t := "011111";
    constant OPC_TESTCY_REG    : opcode_t := "101100";
    constant OPC_TESTCY_IMM    : opcode_t := "101101";
    constant OPC_LOAD_REG    : opcode_t := "010100";
    constant OPC_LOAD_IMM    : opcode_t := "010101";
    constant OPC_INPUT_REG   : opcode_t := "010110";
    constant OPC_INPUT_IMM   : opcode_t := "010111";
    constant OPC_OUTPUT_REG  : opcode_t := "011000";
    constant OPC_OUTPUT_IMM  : opcode_t := "011001";
    constant OPC_FETCH_REG   : opcode_t := "011010";
    constant OPC_FETCH_IMM   : opcode_t := "011011";
    constant OPC_STORE_REG   : opcode_t := "011100";
    constant OPC_STORE_IMM   : opcode_t := "011101";
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
    constant OPC_JUMP        : opcode_t := "110000";
    constant OPC_JZ          : opcode_t := "110001";
    constant OPC_JNZ         : opcode_t := "110010";
    constant OPC_JC          : opcode_t := "110011";
    constant OPC_JNC         : opcode_t := "110100";

    -- Expected-value record so we can check all outputs in one call
    type ctrl_exp_t is record
        alu_op      : alu_op_t;
        reg_write   : std_logic;
        mem_read    : std_logic;
        mem_write   : std_logic;
        io_rd       : std_logic;
        io_wr       : std_logic;
        alu_src     : std_logic;
        jump_cond   : jump_cond_t;
        flag_write  : std_logic;
        reads_reg_a : std_logic;
        reads_reg_b : std_logic;
    end record;

begin

    uut: entity work.instruction_decoder
        port map (
            instruction => instruction,
            alu_op      => alu_op,
            reg_write   => reg_write,
            mem_read    => mem_read,
            mem_write   => mem_write,
            io_rd       => io_rd,
            io_wr       => io_wr,
            imm8        => imm8,
            alu_src     => alu_src,
            reg_dst     => reg_dst,
            jump_cond   => jump_cond,
            reg_src_b   => reg_src_b,
            flag_write  => flag_write,
            reads_reg_a => reads_reg_a,
            reads_reg_b => reads_reg_b
        );

    stim: process
        -- Apply an instruction and wait for propagation
        procedure drive(constant instr : in std_logic_vector(17 downto 0)) is
        begin
            instruction <= instr;
            wait for 1 ns;
        end procedure;

        -- Bulk-check all control outputs against expected values
        procedure check_ctrl(constant exp : in ctrl_exp_t; constant what : in string) is
        begin
            assert alu_op = exp.alu_op report what & ": alu_op" severity error;
            assert reg_write = exp.reg_write report what & ": reg_write" severity error;
            assert mem_read = exp.mem_read report what & ": mem_read" severity error;
            assert mem_write = exp.mem_write report what & ": mem_write" severity error;
            assert io_rd = exp.io_rd report what & ": io_rd" severity error;
            assert io_wr = exp.io_wr report what & ": io_wr" severity error;
            assert alu_src = exp.alu_src report what & ": alu_src" severity error;
            assert jump_cond = exp.jump_cond report what & ": jump_cond" severity error;
            assert flag_write = exp.flag_write report what & ": flag_write" severity error;
            assert reads_reg_a = exp.reads_reg_a report what & ": reads_reg_a" severity error;
            assert reads_reg_b = exp.reads_reg_b report what & ": reads_reg_b" severity error;
        end procedure;

        procedure check_imm(constant exp_imm : in ro2_word; constant what : in string) is
        begin
            assert imm8 = exp_imm report what & ": imm8" severity error;
        end procedure;

        procedure check_regs(constant exp_dst : in std_logic_vector(3 downto 0); constant exp_src_b : in std_logic_vector(3 downto 0); constant what : in string) is
        begin
            assert reg_dst = exp_dst report what & ": reg_dst" severity error;
            assert reg_src_b = exp_src_b report what & ": reg_src_b" severity error;
        end procedure;

        -- Build a register-mode instruction: opcode & sX & sY & 0000
        function mk_reg(constant opc : opcode_t; constant rd : std_logic_vector(3 downto 0); constant rs : std_logic_vector(3 downto 0)) return std_logic_vector is
        begin
            return opc & rd & rs & "0000";
        end function;

        -- Build an immediate-mode instruction: opcode & sX & kk
        function mk_imm(constant opc : opcode_t; constant rd : std_logic_vector(3 downto 0); constant imm : std_logic_vector(7 downto 0)) return std_logic_vector is
        begin
            return opc & rd & imm;
        end function;

        -- Build a jump instruction: opcode & 12-bit address
        function mk_jump(constant opc : opcode_t; constant addr : std_logic_vector(11 downto 0)) return std_logic_vector is
        begin
            return opc & addr;
        end function;

        -- Baseline: all outputs inactive
        constant EXP_NONE : ctrl_exp_t := (
            alu_op      => ALU_NOP,
            reg_write   => '0',
            mem_read    => '0',
            mem_write   => '0',
            io_rd       => '0',
            io_wr       => '0',
            alu_src     => '0',
            jump_cond   => J_NONE,
            flag_write  => '0',
            reads_reg_a => '1',
            reads_reg_b => '1'
        );

        -- NOP: like NONE but also clears reads_reg_a/b
        constant EXP_NOP : ctrl_exp_t := (
            alu_op      => ALU_NOP,
            reg_write   => '0',
            mem_read    => '0',
            mem_write   => '0',
            io_rd       => '0',
            io_wr       => '0',
            alu_src     => '0',
            jump_cond   => J_NONE,
            flag_write  => '0',
            reads_reg_a => '0',
            reads_reg_b => '0'
        );

    begin
        -- NOP
        drive(OPC_NOP & (11 downto 0 => '0'));
        check_ctrl(EXP_NOP, "NOP");

        -- Arithmetic / Logic (register operand)
        drive(mk_reg(OPC_ADD_REG, "0001", "0010"));
        check_ctrl((ALU_ADD, '1','0','0','0','0','0', J_NONE, '1','1','1'), "ADD_REG");
        check_regs("0001", "0010", "ADD_REG");

        drive(mk_reg(OPC_ADDCY_REG, "0010", "0011"));
        check_ctrl((ALU_ADDCY,'1','0','0','0','0','0', J_NONE, '1','1','1'), "ADDCY_REG");
        check_regs("0010", "0011", "ADDCY_REG");

        drive(mk_reg(OPC_SUB_REG, "0011", "0100"));
        check_ctrl((ALU_SUB, '1','0','0','0','0','0', J_NONE, '1','1','1'), "SUB_REG");
        check_regs("0011", "0100", "SUB_REG");

        drive(mk_reg(OPC_SUBCY_REG, "0100", "0101"));
        check_ctrl((ALU_SUBCY,'1','0','0','0','0','0', J_NONE, '1','1','1'), "SUBCY_REG");
        check_regs("0100", "0101", "SUBCY_REG");

        drive(mk_reg(OPC_AND_REG, "0001", "0011"));
        check_ctrl((ALU_AND,'1','0','0','0','0','0', J_NONE, '1','1','1'), "AND_REG");

        drive(mk_reg(OPC_OR_REG, "0001", "0011"));
        check_ctrl((ALU_OR,'1','0','0','0','0','0', J_NONE, '1','1','1'), "OR_REG");

        drive(mk_reg(OPC_XOR_REG, "0001", "0011"));
        check_ctrl((ALU_XOR,'1','0','0','0','0','0', J_NONE, '1','1','1'), "XOR_REG");

        -- Arithmetic / Logic (immediate operand)
        drive(mk_imm(OPC_ADD_IMM, "0001", x"3C"));
        check_ctrl((ALU_ADD,'1','0','0','0','0','1', J_NONE, '1','1','0'), "ADD_IMM");
        check_imm(x"3C", "ADD_IMM");

        drive(mk_imm(OPC_ADDCY_IMM, "0001", x"01"));
        check_ctrl((ALU_ADDCY,'1','0','0','0','0','1', J_NONE, '1','1','0'), "ADDCY_IMM");
        check_imm(x"01", "ADDCY_IMM");

        drive(mk_imm(OPC_SUB_IMM, "0001", x"10"));
        check_ctrl((ALU_SUB,'1','0','0','0','0','1', J_NONE, '1','1','0'), "SUB_IMM");
        check_imm(x"10", "SUB_IMM");

        drive(mk_imm(OPC_SUBCY_IMM, "0001", x"20"));
        check_ctrl((ALU_SUBCY,'1','0','0','0','0','1', J_NONE, '1','1','0'), "SUBCY_IMM");
        check_imm(x"20", "SUBCY_IMM");

        drive(mk_imm(OPC_AND_IMM, "0001", x"AA"));
        check_ctrl((ALU_AND,'1','0','0','0','0','1', J_NONE, '1','1','0'), "AND_IMM");
        check_imm(x"AA", "AND_IMM");

        drive(mk_imm(OPC_OR_IMM, "0001", x"0F"));
        check_ctrl((ALU_OR,'1','0','0','0','0','1', J_NONE, '1','1','0'), "OR_IMM");
        check_imm(x"0F", "OR_IMM");

        drive(mk_imm(OPC_XOR_IMM, "0001", x"FF"));
        check_ctrl((ALU_XOR,'1','0','0','0','0','1', J_NONE, '1','1','0'), "XOR_IMM");
        check_imm(x"FF", "XOR_IMM");

        -- Compare / Test (flag-only, no write-back)
        drive(mk_reg(OPC_COMPARE_REG, "0001", "0010"));
        check_ctrl((ALU_SUB,'0','0','0','0','0','0', J_NONE, '1','1','1'), "COMPARE_REG");

        drive(mk_imm(OPC_COMPARE_IMM, "0001", x"0F"));
        check_ctrl((ALU_SUB,'0','0','0','0','0','1', J_NONE, '1','1','0'), "COMPARE_IMM");
        check_imm(x"0F", "COMPARE_IMM");

        drive(mk_reg(OPC_TEST_REG, "0001", "0010"));
        check_ctrl((ALU_TEST,'0','0','0','0','0','0', J_NONE, '1','1','1'), "TEST_REG");

        drive(mk_imm(OPC_TEST_IMM, "0001", x"F0"));
        check_ctrl((ALU_TEST,'0','0','0','0','0','1', J_NONE, '1','1','0'), "TEST_IMM");
        check_imm(x"F0", "TEST_IMM");

        drive(mk_reg(OPC_COMPARECY_REG, "0001", "0010"));
        check_ctrl((ALU_COMPARECY,'0','0','0','0','0','0', J_NONE, '1','1','1'), "COMPARECY_REG");

        drive(mk_imm(OPC_COMPARECY_IMM, "0001", x"AB"));
        check_ctrl((ALU_COMPARECY,'0','0','0','0','0','1', J_NONE, '1','1','0'), "COMPARECY_IMM");
        check_imm(x"AB", "COMPARECY_IMM");

        drive(mk_reg(OPC_TESTCY_REG, "0001", "0010"));
        check_ctrl((ALU_TESTCY,'0','0','0','0','0','0', J_NONE, '1','1','1'), "TESTCY_REG");

        drive(mk_imm(OPC_TESTCY_IMM, "0001", x"CD"));
        check_ctrl((ALU_TESTCY,'0','0','0','0','0','1', J_NONE, '1','1','0'), "TESTCY_IMM");
        check_imm(x"CD", "TESTCY_IMM");

        -- LOAD / FETCH / STORE / INPUT / OUTPUT
        drive(mk_reg(OPC_LOAD_REG, "0001", "0010"));
        check_ctrl((ALU_PASS_B,'1','0','0','0','0','0', J_NONE, '0','0','1'), "LOAD_REG");

        drive(mk_imm(OPC_LOAD_IMM, "0001", x"7E"));
        check_ctrl((ALU_PASS_B,'1','0','0','0','0','1', J_NONE, '0','0','0'), "LOAD_IMM");
        check_imm(x"7E", "LOAD_IMM");

        drive(mk_reg(OPC_FETCH_REG, "0001", "0010"));
        check_ctrl((ALU_NOP,'1','1','0','0','0','0', J_NONE, '0','0','1'), "FETCH_REG");

        drive(mk_imm(OPC_FETCH_IMM, "0001", x"F0"));
        check_ctrl((ALU_NOP,'1','1','0','0','0','1', J_NONE, '0','0','0'), "FETCH_IMM");
        check_imm(x"F0", "FETCH_IMM");

        drive(mk_reg(OPC_STORE_REG, "0001", "0010"));
        check_ctrl((ALU_NOP,'0','0','1','0','0','0', J_NONE, '0','1','1'), "STORE_REG");

        drive(mk_imm(OPC_STORE_IMM, "0001", x"22"));
        check_ctrl((ALU_NOP,'0','0','1','0','0','1', J_NONE, '0','1','0'), "STORE_IMM");
        check_imm(x"22", "STORE_IMM");

        drive(mk_reg(OPC_INPUT_REG, "0001", "0010"));
        check_ctrl((ALU_NOP,'1','0','0','1','0','0', J_NONE, '0','0','1'), "INPUT_REG");

        drive(mk_imm(OPC_INPUT_IMM, "0001", x"A5"));
        check_ctrl((ALU_NOP,'1','0','0','1','0','1', J_NONE, '0','0','0'), "INPUT_IMM");
        check_imm(x"A5", "INPUT_IMM");

        drive(mk_reg(OPC_OUTPUT_REG, "0001", "0010"));
        check_ctrl((ALU_NOP,'0','0','0','0','1','0', J_NONE, '0','1','1'), "OUTPUT_REG");

        drive(mk_imm(OPC_OUTPUT_IMM, "0001", x"F0"));
        check_ctrl((ALU_NOP,'0','0','0','0','1','1', J_NONE, '0','1','0'), "OUTPUT_IMM");
        check_imm(x"F0", "OUTPUT_IMM");

        -- Shifts / Rotates (write + update flags, no reg_b)
        drive(mk_imm(OPC_RL,  "0001", x"00"));
        check_ctrl((ALU_RL,'1','0','0','0','0','0', J_NONE, '1','1','0'), "RL");

        drive(mk_imm(OPC_RR,  "0001", x"00"));
        check_ctrl((ALU_RR,'1','0','0','0','0','0', J_NONE, '1','1','0'), "RR");

        drive(mk_imm(OPC_SL0, "0001", x"00"));
        check_ctrl((ALU_SL0,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SL0");

        drive(mk_imm(OPC_SL1, "0001", x"00"));
        check_ctrl((ALU_SL1,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SL1");

        drive(mk_imm(OPC_SLA, "0001", x"00"));
        check_ctrl((ALU_SLA,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SLA");

        drive(mk_imm(OPC_SLX, "0001", x"00"));
        check_ctrl((ALU_SLX,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SLX");

        drive(mk_imm(OPC_SR0, "0001", x"00"));
        check_ctrl((ALU_SR0,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SR0");

        drive(mk_imm(OPC_SR1, "0001", x"00"));
        check_ctrl((ALU_SR1,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SR1");

        drive(mk_imm(OPC_SRA, "0001", x"00"));
        check_ctrl((ALU_SRA,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SRA");

        drive(mk_imm(OPC_SRX, "0001", x"00"));
        check_ctrl((ALU_SRX,'1','0','0','0','0','0', J_NONE, '1','1','0'), "SRX");

        -- Jumps / Branches
        drive(mk_jump(OPC_JUMP, x"00C"));
        check_ctrl((ALU_NOP,'0','0','0','0','0','0', J_UNCOND, '0','0','0'), "JUMP");

        drive(mk_jump(OPC_JZ, x"00C"));
        check_ctrl((ALU_NOP,'0','0','0','0','0','0', J_Z, '0','0','0'), "JZ");

        drive(mk_jump(OPC_JNZ, x"00C"));
        check_ctrl((ALU_NOP,'0','0','0','0','0','0', J_NZ, '0','0','0'), "JNZ");

        drive(mk_jump(OPC_JC, x"00C"));
        check_ctrl((ALU_NOP,'0','0','0','0','0','0', J_C, '0','0','0'), "JC");

        drive(mk_jump(OPC_JNC, x"00C"));
        check_ctrl((ALU_NOP,'0','0','0','0','0','0', J_NC, '0','0','0'), "JNC");

        report "instruction_decoder_tb: Completed";
        wait;
    end process;

end architecture;
