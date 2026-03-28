----------------------------------------------------------------------------------
-- Testbench for control_unit (integration level)
--
-- Checks the interplay between decoder, branch logic, and PC:
--   - PC increments normally when not stalled
--   - All write/read signals are suppressed during stall
--   - PC freezes during stall and resumes afterwards
--   - flush_out fires on a taken branch and is suppressed during stall
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.alu_pkg.all;
use work.common.all;

entity control_unit_tb is
end entity;

architecture sim of control_unit_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '0';
    signal stall_in    : std_logic := '0';
    signal instruction : std_logic_vector(17 downto 0) := (others => '0');
    signal carry_in    : std_logic := '0';
    signal zero_in     : std_logic := '0';

    signal pc_out      : std_logic_vector(11 downto 0);
    signal flush_out   : std_logic;
    signal alu_op      : alu_op_t;
    signal reg_write   : std_logic;
    signal mem_read    : std_logic;
    signal mem_write   : std_logic;
    signal io_rd       : std_logic;
    signal io_wr       : std_logic;
    signal alu_src     : std_logic;
    signal imm_out     : ro2_word;
    signal reg_dst     : std_logic_vector(3 downto 0);
    signal reg_src_b   : std_logic_vector(3 downto 0);
    signal flag_write  : std_logic;
    signal reads_reg_a : std_logic;
    signal reads_reg_b : std_logic;

    -- local copies of opcodes used in stimulus
    subtype opcode_t is std_logic_vector(5 downto 0);
    constant OPC_ADD_REG : opcode_t := "000010";
    constant OPC_JUMP    : opcode_t := "110000";
    constant OPC_JZ      : opcode_t := "110001";

begin

    clk <= not clk after CLK_PERIOD / 2;

    uut: entity work.control_unit
        port map (
            clk         => clk,
            reset       => reset,
            stall_in    => stall_in,
            instruction => instruction,
            carry_in    => carry_in,
            zero_in     => zero_in,
            pc_out      => pc_out,
            flush_out   => flush_out,
            alu_op      => alu_op,
            reg_write   => reg_write,
            mem_read    => mem_read,
            mem_write   => mem_write,
            io_rd       => io_rd,
            io_wr       => io_wr,
            alu_src     => alu_src,
            imm_out     => imm_out,
            reg_dst     => reg_dst,
            reg_src_b   => reg_src_b,
            flag_write  => flag_write,
            reads_reg_a => reads_reg_a,
            reads_reg_b => reads_reg_b
        );

    stimulus_process: process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        variable pc_before : std_logic_vector(11 downto 0);
    begin
        -- Reset
        report "control_unit_tb: reset";
        stall_in <= '0';
        instruction <= (others => '0');
        zero_in <= '0';
        carry_in <= '0';

        reset <= '1';
        tick;
        tick;
        reset <= '0';
        tick;

        -- PC must increment each cycle when not stalled
        pc_before := pc_out;
        tick;
        assert pc_out = std_logic_vector(unsigned(pc_before) + 1)
            report "Error: PC must increment when stall_in=0" severity error;

        -- Stall gating: all write/read/flag signals must be suppressed
        report "control_unit_tb: stall gating";
        instruction <= OPC_ADD_REG & "0001" & "0010" & "0000"; -- ADD s1, s2
        wait for 1 ns;
        assert reg_write = '1'
            report "Precondition failed: reg_write expected 1 when not stalled" severity error;

        pc_before := pc_out;
        stall_in <= '1';
        wait for 1 ns;
        assert reg_write = '0' report "Error: reg_write must be 0 during stall" severity error;
        assert mem_read  = '0' report "Error: mem_read must be 0 during stall" severity error;
        assert mem_write = '0' report "Error: mem_write must be 0 during stall" severity error;
        assert io_rd     = '0' report "Error: io_rd must be 0 during stall" severity error;
        assert io_wr     = '0' report "Error: io_wr must be 0 during stall" severity error;
        assert flag_write = '0' report "Error: flag_write must be 0 during stall" severity error;
        assert flush_out = '0' report "Error: flush_out must be 0 during stall" severity error;

        -- PC must freeze while stalled
        tick;
        assert pc_out = pc_before
            report "Error: PC must freeze during stall" severity error;

        -- PC resumes after stall released
        stall_in <= '0';
        tick;
        assert pc_out /= pc_before
            report "Error: PC must advance after stall released" severity error;

        -- flush_out: taken branch vs. not-taken, plus stall suppression
        report "control_unit_tb: flush_out";

        -- unconditional jump => flush must fire
        instruction <= OPC_JUMP & x"00C";
        wait for 1 ns;
        assert flush_out = '1'
            report "Error: flush_out must be 1 for unconditional jump when not stalled" severity error;
        tick;

        -- JZ with Z=0 => branch not taken => no flush
        instruction <= OPC_JZ & x"00C";
        zero_in <= '0';
        wait for 1 ns;
        assert flush_out = '0'
            report "Error: flush_out must be 0 for JZ when Z=0" severity error;
        tick;

        -- unconditional jump during stall => flush must be suppressed
        stall_in <= '1';
        instruction <= OPC_JUMP & x"00C";
        wait for 1 ns;
        assert flush_out = '0'
            report "Error: flush_out must be suppressed during stall" severity error;
        tick;

        report "control_unit_tb: Completed";
        wait;
    end process;

end architecture;
