----------------------------------------------------------------------------------
-- Testbench for program_counter
--
-- Covers: synchronous reset, enable gating (hold during stall),
-- normal increment, absolute jump loading, and the interaction
-- between enable=0 and branch_jump=1 (jump must be blocked).
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity program_counter_tb is
end entity;

architecture sim of program_counter_tb is

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal branch_jump  : std_logic := '0';
    signal enable       : std_logic := '0';
    signal jump_address : std_logic_vector(11 downto 0) := (others => '0');
    signal pc_out       : std_logic_vector(11 downto 0);

    constant CLK_PERIOD : time := 20 ns;

begin

    uut: entity work.program_counter
        port map (
            clk          => clk,
            reset        => reset,
            branch_jump  => branch_jump,
            enable       => enable,
            jump_address => jump_address,
            pc_out       => pc_out
        );

    -- free-running clock
    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    stim: process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        variable pc_prev : std_logic_vector(11 downto 0);
    begin
        -- 1) Reset clears PC to 0
        reset <= '1';
        enable <= '1';
        branch_jump <= '0';
        jump_address <= x"123";
        tick;
        assert pc_out = (pc_out'range => '0') report "Error: PC must be 0 after reset" severity error;

        reset <= '0';

        -- 2) enable=0 must hold the PC value
        enable <= '0';
        tick;
        pc_prev := pc_out;
        tick;
        assert pc_out = pc_prev report "Error: PC must hold when enable=0" severity error;

        -- 3) enable=1, no jump => PC increments by 1 each cycle
        enable <= '1';
        branch_jump <= '0';
        pc_prev := pc_out;
        tick;
        assert pc_out = std_logic_vector(unsigned(pc_prev) + 1)
            report "Error: PC must increment by 1 when enable=1 and branch_jump=0" severity error;

        pc_prev := pc_out;
        tick;
        assert pc_out = std_logic_vector(unsigned(pc_prev) + 1)
            report "Error: PC must keep incrementing when enabled" severity error;

        -- 4) Absolute jump loads the target address
        jump_address <= x"00A";
        branch_jump <= '1';
        tick;
        assert pc_out = x"00A" report "Error: PC must load jump_address when branch_jump=1" severity error;

        -- 5) After jump, continue incrementing normally
        branch_jump <= '0';
        pc_prev := pc_out;
        tick;
        assert pc_out = std_logic_vector(unsigned(pc_prev) + 1)
            report "Error: PC must increment after jump when branch_jump returns to 0" severity error;

        -- 6) enable=0 must block even a jump
        enable <= '0';
        jump_address <= x"0F0";
        branch_jump <= '1';
        pc_prev := pc_out;
        tick;
        assert pc_out = pc_prev report "Error: PC must not change when enable=0 (even if branch_jump=1)" severity error;

        report "program_counter_tb completed";
        wait;
    end process;

end architecture;
