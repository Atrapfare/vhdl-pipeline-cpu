----------------------------------------------------------------------------------
-- ALU Testbench -- exhaustive check of every ALU operation
--
-- Uses an expect() helper to drive inputs and assert result, carry, zero
-- in a single call. Covers edge cases like overflow, underflow, parity,
-- zero results, and carry-in behaviour for each operation.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.alu_pkg.all;
use std.env.all;

entity alu_tb is
end entity;

architecture sim of alu_tb is

    signal a_i    : std_logic_vector(7 downto 0) := (others => '0');
    signal b_i    : std_logic_vector(7 downto 0) := (others => '0');
    signal c_i    : std_logic := '0';
    signal z_i    : std_logic := '0';
    signal op     : alu_op_t := ALU_NOP;
    signal result : std_logic_vector(7 downto 0);
    signal c_o    : std_logic;
    signal z_o    : std_logic;

begin

    dut: entity work.alu(rtl)
        port map (
            a_i    => a_i,
            b_i    => b_i,
            c_i    => c_i,
            z_i    => z_i,
            op     => op,
            result => result,
            c_o    => c_o,
            z_o    => z_o
        );

    stim: process

        -- Drive all inputs, wait for combinational settle, check outputs
        procedure expect(
            constant a_in  : std_logic_vector(7 downto 0);
            constant b_in  : std_logic_vector(7 downto 0);
            constant c_in  : std_logic;
            constant z_in  : std_logic;
            constant op_in : alu_op_t;
            constant exp_r : std_logic_vector(7 downto 0);
            constant exp_c : std_logic;
            constant exp_z : std_logic
        ) is
        begin
            a_i <= a_in;
            b_i <= b_in;
            c_i <= c_in;
            z_i <= z_in;
            op  <= op_in;
            wait for 1 ns;

            assert result = exp_r
                report "RESULT mismatch for op=" & alu_op_t'image(op_in)
                severity error;

            assert c_o = exp_c
                report "C_O mismatch for op=" & alu_op_t'image(op_in)
                severity error;

            assert z_o = exp_z
                report "Z_O mismatch for op=" & alu_op_t'image(op_in)
                severity error;
        end procedure;
    begin

        -- Addition
        expect(x"05", x"03", '0', '0', ALU_ADD, x"08", '0', '0');
        expect(x"00", x"00", '0', '0', ALU_ADD, x"00", '0', '1');  -- 0+0, z=1
        expect(x"00", x"42", '0', '0', ALU_ADD, x"42", '0', '0');
        expect(x"42", x"00", '0', '0', ALU_ADD, x"42", '0', '0');
        expect(x"FF", x"01", '0', '0', ALU_ADD, x"00", '1', '1');  -- overflow, c=1, z=1
        expect(x"FF", x"02", '0', '0', ALU_ADD, x"01", '1', '0');  -- overflow, c=1
        expect(x"FF", x"FF", '0', '0', ALU_ADD, x"FE", '1', '0');  -- max+max
        expect(x"7F", x"80", '0', '0', ALU_ADD, x"FF", '0', '0');  -- near overflow, no carry
        -- ADD ignores z_i
        expect(x"FF", x"01", '0', '1', ALU_ADD, x"00", '1', '1');
        expect(x"05", x"03", '0', '1', ALU_ADD, x"08", '0', '0');

        -- Addition with carry
        expect(x"05", x"03", '0', '0', ALU_ADDCY, x"08", '0', '0');
        expect(x"05", x"03", '1', '0', ALU_ADDCY, x"09", '0', '0');  -- carry in adds 1
        expect(x"FF", x"00", '1', '0', ALU_ADDCY, x"00", '1', '0');  -- wrap, z_i=0 so z=0
        expect(x"FF", x"00", '1', '1', ALU_ADDCY, x"00", '1', '1');  -- wrap, z_i=1 so z=1
        expect(x"FF", x"FF", '1', '0', ALU_ADDCY, x"FF", '1', '0');
        expect(x"00", x"00", '1', '0', ALU_ADDCY, x"01", '0', '0');  -- 0+0+1=1
        expect(x"80", x"80", '0', '1', ALU_ADDCY, x"00", '1', '1'); -- result=0, z_i=1 -> z=1
        expect(x"80", x"80", '0', '0', ALU_ADDCY, x"00", '1', '0'); -- result=0, z_i=0 -> z=0
        expect(x"05", x"03", '0', '1', ALU_ADDCY, x"08", '0', '0'); -- result!=0, z_i=1 -> z=0
        expect(x"00", x"00", '0', '1', ALU_ADDCY, x"00", '0', '1'); -- result=0, z_i=1 -> z=1

        -- Subtraction
        expect(x"08", x"02", '0', '0', ALU_SUB, x"06", '0', '0');
        expect(x"42", x"42", '0', '0', ALU_SUB, x"00", '0', '1');  -- equal, z=1
        expect(x"00", x"00", '0', '0', ALU_SUB, x"00", '0', '1');
        expect(x"00", x"01", '0', '0', ALU_SUB, x"FF", '1', '0');  -- underflow, borrow
        expect(x"FF", x"01", '0', '0', ALU_SUB, x"FE", '0', '0');
        expect(x"FF", x"FF", '0', '0', ALU_SUB, x"00", '0', '1');
        expect(x"01", x"FF", '0', '0', ALU_SUB, x"02", '1', '0');  -- 1-FF wraps
        -- SUB ignores z_i
        expect(x"42", x"42", '0', '1', ALU_SUB, x"00", '0', '1');

        -- Subtraction with carry (borrow)
        expect(x"08", x"02", '0', '0', ALU_SUBCY, x"06", '0', '0');
        expect(x"08", x"02", '1', '0', ALU_SUBCY, x"05", '0', '0');  -- borrow subtracts 1
        expect(x"01", x"00", '1', '0', ALU_SUBCY, x"00", '0', '0');  -- result=0, z_i=0 -> z=0
        expect(x"01", x"00", '1', '1', ALU_SUBCY, x"00", '0', '1');  -- result=0, z_i=1 -> z=1
        expect(x"00", x"00", '1', '0', ALU_SUBCY, x"FF", '1', '0');  -- borrow causes underflow
        expect(x"42", x"42", '1', '0', ALU_SUBCY, x"FF", '1', '0');  -- equal with borrow
        expect(x"42", x"42", '0', '1', ALU_SUBCY, x"00", '0', '1'); -- result=0, z_i=1 -> z=1
        expect(x"05", x"03", '0', '1', ALU_SUBCY, x"02", '0', '0'); -- result!=0, z_i=1 -> z=0

        -- Bitwise AND
        expect(x"0F", x"33", '0', '0', ALU_AND, x"03", '0', '0');
        expect(x"FF", x"00", '0', '0', ALU_AND, x"00", '0', '1');  -- mask with zero
        expect(x"00", x"FF", '0', '0', ALU_AND, x"00", '0', '1');
        expect(x"AA", x"FF", '0', '0', ALU_AND, x"AA", '0', '0');  -- identity
        expect(x"F0", x"0F", '0', '0', ALU_AND, x"00", '0', '1');  -- non-overlapping bits
        expect(x"FF", x"FF", '0', '0', ALU_AND, x"FF", '0', '0');
        expect(x"80", x"80", '0', '0', ALU_AND, x"80", '0', '0');  -- single bit
        expect(x"80", x"7F", '0', '0', ALU_AND, x"00", '0', '1');

        -- Bitwise OR
        expect(x"0F", x"30", '0', '0', ALU_OR, x"3F", '0', '0');
        expect(x"AA", x"00", '0', '0', ALU_OR, x"AA", '0', '0');
        expect(x"00", x"55", '0', '0', ALU_OR, x"55", '0', '0');
        expect(x"00", x"00", '0', '0', ALU_OR, x"00", '0', '1');   -- 0|0, z=1
        expect(x"00", x"FF", '0', '0', ALU_OR, x"FF", '0', '0');
        expect(x"F0", x"0F", '0', '0', ALU_OR, x"FF", '0', '0');   -- non-overlapping -> all ones

        -- Bitwise XOR
        expect(x"AA", x"0F", '0', '0', ALU_XOR, x"A5", '0', '0');
        expect(x"55", x"55", '0', '0', ALU_XOR, x"00", '0', '1');  -- same value -> zero
        expect(x"FF", x"FF", '0', '0', ALU_XOR, x"00", '0', '1');
        expect(x"AA", x"00", '0', '0', ALU_XOR, x"AA", '0', '0');
        expect(x"AA", x"FF", '0', '0', ALU_XOR, x"55", '0', '0');  -- XOR FF = bit invert
        expect(x"00", x"00", '0', '0', ALU_XOR, x"00", '0', '1');

        -- Rotate left (carry = old bit 7, bit 0 = old bit 7)
        expect("10000001", x"00", '0', '0', ALU_RL, "00000011", '1', '0');
        expect("01000000", x"00", '0', '0', ALU_RL, "10000000", '0', '0');
        expect("00000001", x"00", '0', '0', ALU_RL, "00000010", '0', '0');
        expect("10000000", x"00", '0', '0', ALU_RL, "00000001", '1', '0');
        expect("00000000", x"00", '0', '0', ALU_RL, "00000000", '0', '1');
        expect("11111111", x"00", '0', '0', ALU_RL, "11111111", '1', '0');

        -- Rotate right (carry = old bit 0, bit 7 = old bit 0)
        expect("10000001", x"00", '0', '0', ALU_RR, "11000000", '1', '0');
        expect("00000010", x"00", '0', '0', ALU_RR, "00000001", '0', '0');
        expect("00000001", x"00", '0', '0', ALU_RR, "10000000", '1', '0');
        expect("00000000", x"00", '0', '0', ALU_RR, "00000000", '0', '1');
        expect("11111111", x"00", '0', '0', ALU_RR, "11111111", '1', '0');

        -- Shift left, fill with 0 (carry = old bit 7)
        expect("00000001", x"00", '0', '0', ALU_SL0, "00000010", '0', '0');
        expect("10000000", x"00", '0', '0', ALU_SL0, "00000000", '1', '1');
        expect("01000000", x"00", '0', '0', ALU_SL0, "10000000", '0', '0');
        expect("11111111", x"00", '0', '0', ALU_SL0, "11111110", '1', '0');
        expect("00000000", x"00", '0', '0', ALU_SL0, "00000000", '0', '1');

        -- Shift left, fill with 1 (carry = old bit 7)
        expect("00000001", x"00", '0', '0', ALU_SL1, "00000011", '0', '0');
        expect("10000000", x"00", '0', '0', ALU_SL1, "00000001", '1', '0');
        expect("00000000", x"00", '0', '0', ALU_SL1, "00000001", '0', '0');
        expect("11111111", x"00", '0', '0', ALU_SL1, "11111111", '1', '0');

        -- Shift left through carry (bit 0 = old carry, carry = old bit 7)
        expect("00000001", x"00", '0', '0', ALU_SLA, "00000010", '0', '0');
        expect("00000001", x"00", '1', '0', ALU_SLA, "00000011", '0', '0');
        expect("10000000", x"00", '0', '0', ALU_SLA, "00000000", '1', '1');
        expect("10000000", x"00", '1', '0', ALU_SLA, "00000001", '1', '0');
        expect("00000000", x"00", '1', '0', ALU_SLA, "00000001", '0', '0');

        -- Shift left, replicate bit 0 (carry = old bit 7)
        expect("00000001", x"00", '0', '0', ALU_SLX, "00000011", '0', '0');
        expect("00000010", x"00", '0', '0', ALU_SLX, "00000100", '0', '0');
        expect("10000001", x"00", '0', '0', ALU_SLX, "00000011", '1', '0');
        expect("10000000", x"00", '0', '0', ALU_SLX, "00000000", '1', '1');

        -- Shift right, fill with 0 (carry = old bit 0)
        expect("10000000", x"00", '0', '0', ALU_SR0, "01000000", '0', '0');
        expect("00000001", x"00", '0', '0', ALU_SR0, "00000000", '1', '1');
        expect("00000010", x"00", '0', '0', ALU_SR0, "00000001", '0', '0');
        expect("11111111", x"00", '0', '0', ALU_SR0, "01111111", '1', '0');

        -- Shift right, fill with 1 (carry = old bit 0)
        expect("10000000", x"00", '0', '0', ALU_SR1, "11000000", '0', '0');
        expect("00000001", x"00", '0', '0', ALU_SR1, "10000000", '1', '0');
        expect("00000000", x"00", '0', '0', ALU_SR1, "10000000", '0', '0');
        expect("11111111", x"00", '0', '0', ALU_SR1, "11111111", '1', '0');

        -- Shift right through carry (bit 7 = old carry, carry = old bit 0)
        expect("10000000", x"00", '0', '0', ALU_SRA, "01000000", '0', '0');
        expect("10000000", x"00", '1', '0', ALU_SRA, "11000000", '0', '0');
        expect("00000001", x"00", '0', '0', ALU_SRA, "00000000", '1', '1');
        expect("00000001", x"00", '1', '0', ALU_SRA, "10000000", '1', '0');
        expect("00000000", x"00", '1', '0', ALU_SRA, "10000000", '0', '0');

        -- Shift right, replicate MSB / arithmetic (carry = old bit 0)
        expect("10000001", x"00", '0', '0', ALU_SRX, "11000000", '1', '0');
        expect("00000010", x"00", '0', '0', ALU_SRX, "00000001", '0', '0');
        expect("10000000", x"00", '0', '0', ALU_SRX, "11000000", '0', '0');
        expect("01000000", x"00", '0', '0', ALU_SRX, "00100000", '0', '0');
        expect("00000001", x"00", '0', '0', ALU_SRX, "00000000", '1', '1');

        -- Passthrough B (result = B, A and carry ignored)
        expect(x"00", x"5A", '0', '0', ALU_PASS_B, x"5A", '0', '0');
        expect(x"FF", x"42", '0', '0', ALU_PASS_B, x"42", '0', '0');
        expect(x"FF", x"00", '0', '0', ALU_PASS_B, x"00", '0', '1');  -- B=0 -> z=1
        expect(x"00", x"FF", '0', '0', ALU_PASS_B, x"FF", '0', '0');
        expect(x"00", x"A5", '1', '0', ALU_PASS_B, x"A5", '0', '0');

        -- TEST (result = A AND B, carry = odd parity of result)
        expect(x"FF", x"01", '0', '0', ALU_TEST, x"01", '1', '0');  -- 1 bit set, odd parity
        expect(x"FF", x"03", '0', '0', ALU_TEST, x"03", '0', '0');  -- 2 bits, even parity
        expect(x"FF", x"07", '0', '0', ALU_TEST, x"07", '1', '0');  -- 3 bits, odd parity
        expect(x"FF", x"FF", '0', '0', ALU_TEST, x"FF", '0', '0');  -- 8 bits, even parity
        expect(x"F0", x"0F", '0', '0', ALU_TEST, x"00", '0', '1');  -- zero result
        expect(x"AA", x"55", '0', '0', ALU_TEST, x"00", '0', '1');  -- non-overlapping, z=1
        expect(x"AA", x"FF", '0', '0', ALU_TEST, x"AA", '0', '0');  -- 4 bits, even
        expect(x"0F", x"37", '0', '0', ALU_TEST, x"07", '1', '0');  -- 3 bits, odd
        expect(x"FF", x"01", '1', '0', ALU_TEST, x"01", '1', '0');  -- carry in ignored

        -- COMPARECY (like SUBCY but no writeback)
        expect(x"42", x"42", '0', '1', ALU_COMPARECY, x"00", '0', '1'); -- equal, z_i=1 -> z=1
        expect(x"42", x"42", '0', '0', ALU_COMPARECY, x"00", '0', '0'); -- equal, z_i=0 -> z=0
        expect(x"42", x"42", '1', '1', ALU_COMPARECY, x"FF", '1', '0'); -- borrow breaks zero
        expect(x"05", x"03", '0', '0', ALU_COMPARECY, x"02", '0', '0');
        expect(x"00", x"01", '0', '0', ALU_COMPARECY, x"FF", '1', '0'); -- underflow
        expect(x"01", x"00", '1', '1', ALU_COMPARECY, x"00", '0', '1'); -- 1-0-1=0, z_i=1 -> z=1
        expect(x"01", x"00", '1', '0', ALU_COMPARECY, x"00", '0', '0'); -- 1-0-1=0, z_i=0 -> z=0

        -- TESTCY (like TEST but chains c and z)
        expect(x"FF", x"01", '0', '1', ALU_TESTCY, x"01", '1', '0'); -- odd parity, c_i=0 -> c=1
        expect(x"FF", x"03", '0', '1', ALU_TESTCY, x"03", '0', '0'); -- even parity, c_i=0 -> c=0, result!=0
        expect(x"FF", x"03", '1', '1', ALU_TESTCY, x"03", '1', '0'); -- even parity, c_i=1 -> c=1
        expect(x"F0", x"0F", '0', '1', ALU_TESTCY, x"00", '0', '1'); -- zero result, z_i=1 -> z=1
        expect(x"F0", x"0F", '0', '0', ALU_TESTCY, x"00", '0', '0'); -- zero result, z_i=0 -> z=0
        expect(x"F0", x"0F", '1', '1', ALU_TESTCY, x"00", '1', '1'); -- zero, c_i=1 -> c=1, z_i=1 -> z=1
        expect(x"AA", x"55", '1', '0', ALU_TESTCY, x"00", '1', '0'); -- zero, c_i=1 -> c=1, z_i=0 -> z=0
        expect(x"FF", x"FF", '1', '0', ALU_TESTCY, x"FF", '1', '0'); -- even parity OR c_i=1 -> c=1

        -- NOP (result always zero)
        expect(x"FF", x"FF", '0', '0', ALU_NOP, x"00", '0', '1');
        expect(x"42", x"A5", '1', '0', ALU_NOP, x"00", '0', '1');
        expect(x"00", x"00", '0', '0', ALU_NOP, x"00", '0', '1');

        report "All ALU tests passed." severity note;
        stop;
        wait;
    end process;

end architecture;
