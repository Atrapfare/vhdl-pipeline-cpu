----------------------------------------------------------------------------------
-- Control Unit (top-level) -- wires decoder, branch logic, and program counter
-- together and exposes the control signals to the rest of the CPU.
--
-- When stall_in is asserted all write/read outputs are suppressed and the
-- PC freezes, so the pipeline can insert a bubble without side effects.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.alu_pkg.all;
use work.controlunit_pkg.all;
use work.common.all;

entity control_unit is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        stall_in    : in  std_logic;                      -- hazard stall
        instruction : in  std_logic_vector(17 downto 0);  -- 18-bit instruction word
        carry_in    : in  std_logic;
        zero_in     : in  std_logic;
        pc_out      : out std_logic_vector(11 downto 0);  -- next instruction address
        flush_out   : out std_logic;                      -- pipeline flush on taken branch
        alu_op      : out alu_op_t;
        reg_write   : out std_logic;
        mem_read    : out std_logic;
        mem_write   : out std_logic;
        io_rd       : out std_logic;
        io_wr       : out std_logic;
        alu_src     : out std_logic;                      -- 0=register, 1=immediate
        imm_out     : out ro2_word;
        reg_dst     : out std_logic_vector(3 downto 0);
        reg_src_b   : out std_logic_vector(3 downto 0);
        flag_write  : out std_logic;
        reads_reg_a : out std_logic;
        reads_reg_b : out std_logic
    );
end control_unit;

architecture rtl of control_unit is

    -- signals between decoder and branch logic
    signal jump_cond   : jump_cond_t := J_NONE;
    signal jump_enable : std_logic := '0';
    signal branch_taken: std_logic := '0';

    -- signals feeding the program counter
    signal pc_branch_jump : std_logic := '0';
    signal pc_jump_address: std_logic_vector(11 downto 0) := (others => '0');

    -- raw decoder outputs (before stall gating)
    signal reg_write_dec       : std_logic := '0';
    signal mem_write_dec       : std_logic := '0';
    signal mem_read_dec        : std_logic := '0';
    signal io_wr_dec           : std_logic := '0';
    signal io_rd_dec           : std_logic := '0';
    signal flag_write_dec      : std_logic := '0';

    signal pc_enable_sig       : std_logic := '0';

begin

    -- 1) Instruction decoder -- purely combinational
    decoder_inst: entity work.instruction_decoder
    port map (
        instruction => instruction,
        alu_op      => alu_op,
        reg_write   => reg_write_dec,
        mem_read    => mem_read_dec,
        mem_write   => mem_write_dec,
        io_rd       => io_rd_dec,
        io_wr       => io_wr_dec,
        imm8        => imm_out,
        alu_src     => alu_src,
        reg_dst     => reg_dst,
        jump_cond   => jump_cond,
        reg_src_b   => reg_src_b,
        flag_write  => flag_write_dec,
        reads_reg_a => reads_reg_a,
        reads_reg_b => reads_reg_b
    );

    -- 2) Branch logic -- evaluates jump condition vs. flags
    branch_logic_inst: entity work.branch_logic
    port map (
        carry_in     => carry_in,
        zero_in      => zero_in,
        jump_cond_in => jump_cond,
        jump_enable  => jump_enable,
        branch_taken => branch_taken
    );

    -- 3) Program counter -- clocked, increments or loads jump target
    pc_inst: entity work.program_counter
    port map (
        clk          => clk,
        reset        => reset,
        enable       => pc_enable_sig,
        branch_jump  => pc_branch_jump,
        jump_address => pc_jump_address,
        pc_out       => pc_out
    );

    -- Stall gating -- suppress all side effects during a pipeline stall
    pc_enable_sig <= '0' when stall_in = '1' else '1';

    reg_write  <= reg_write_dec  when stall_in = '0' else '0';
    mem_write  <= mem_write_dec  when stall_in = '0' else '0';
    mem_read   <= mem_read_dec   when stall_in = '0' else '0';
    io_wr      <= io_wr_dec      when stall_in = '0' else '0';
    io_rd      <= io_rd_dec      when stall_in = '0' else '0';
    flag_write <= flag_write_dec when stall_in = '0' else '0';

    -- Jump / branch wiring
    -- The 12-bit jump target sits in the lower bits of the instruction
    pc_jump_address <= instruction(11 downto 0);

    -- jump_enable is '1' for any instruction that is a branch/jump
    with jump_cond select
        jump_enable <=
            '0' when J_NONE,
            '1' when others;

    -- PC actually jumps only when the condition is also met
    pc_branch_jump <= jump_enable and branch_taken;

    -- Flush the pipeline when a branch is taken (no delay slot)
    flush_out <= pc_branch_jump when stall_in = '0' else '0';

end rtl;
