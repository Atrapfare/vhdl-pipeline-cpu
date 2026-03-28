----------------------------------------------------------------------------------
-- Testbench for branch_logic
--
-- Exercises every jump condition (J_NONE, J_UNCOND, J_Z, J_NZ, J_C, J_NC)
-- with matching and non-matching flag states. Also verifies that nothing
-- fires when jump_enable is deasserted.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.controlunit_pkg.all;

entity branch_logic_tb is
end entity;

architecture sim of branch_logic_tb is

    signal carry_in     : std_logic := '0';
    signal zero_in      : std_logic := '0';
    signal jump_cond_in : jump_cond_t := J_NONE;
    signal jump_enable  : std_logic := '0';
    signal branch_taken : std_logic;

begin

    uut: entity work.branch_logic
        port map (
            carry_in     => carry_in,
            zero_in      => zero_in,
            jump_cond_in => jump_cond_in,
            jump_enable  => jump_enable,
            branch_taken => branch_taken
        );

    stim: process
    begin
        -- jump_enable = 0 must suppress any branch, regardless of condition and flags
        jump_enable  <= '0';
        jump_cond_in <= J_UNCOND;
        carry_in     <= '1';
        zero_in      <= '1';
        wait for 1 ns;
        assert branch_taken = '0' report "Error: branch_taken must be 0 when jump_enable=0" severity error;

        -- From here on, jump_enable = 1
        jump_enable <= '1';

        -- J_NONE: never taken even with enable
        jump_cond_in <= J_NONE;
        carry_in <= '0';
        zero_in  <= '0';
        wait for 1 ns;
        assert branch_taken = '0' report "Error: J_NONE must not be taken" severity error;

        -- J_UNCOND: always taken
        jump_cond_in <= J_UNCOND;
        carry_in <= '0';
        zero_in  <= '0';
        wait for 1 ns;
        assert branch_taken = '1' report "Error: J_UNCOND must be taken" severity error;

        -- J_Z: taken when Z=1, not taken when Z=0
        jump_cond_in <= J_Z;
        zero_in <= '1';
        wait for 1 ns;
        assert branch_taken = '1' report "Error: J_Z must be taken when Z=1" severity error;

        zero_in <= '0';
        wait for 1 ns;
        assert branch_taken = '0' report "Error: J_Z must not be taken when Z=0" severity error;

        -- J_NZ: opposite of J_Z
        jump_cond_in <= J_NZ;
        zero_in <= '0';
        wait for 1 ns;
        assert branch_taken = '1' report "Error: J_NZ must be taken when Z=0" severity error;

        zero_in <= '1';
        wait for 1 ns;
        assert branch_taken = '0' report "Error: J_NZ must not be taken when Z=1" severity error;

        -- J_C: taken when C=1
        jump_cond_in <= J_C;
        carry_in <= '1';
        wait for 1 ns;
        assert branch_taken = '1' report "Error: J_C must be taken when C=1" severity error;

        carry_in <= '0';
        wait for 1 ns;
        assert branch_taken = '0' report "Error: J_C must not be taken when C=0" severity error;

        -- J_NC: taken when C=0
        jump_cond_in <= J_NC;
        carry_in <= '0';
        wait for 1 ns;
        assert branch_taken = '1' report "Error: J_NC must be taken when C=0" severity error;

        carry_in <= '1';
        wait for 1 ns;
        assert branch_taken = '0' report "Error: J_NC must not be taken when C=1" severity error;

        report "branch_logic_tb completed";
        wait;
    end process;

end architecture;
