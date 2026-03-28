----------------------------------------------------------------------------------
-- Register File Testbench -- exercises the 16x8-bit register file
--
-- Covers: reset, write/read-back, dual-port read, write protection,
-- overwrite, register isolation, all-16 sweep, read-first (old value
-- returned on same-cycle write), and reset clearing.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common.all;
use std.env.all;

entity regfile_tb is
end entity;

architecture sim of regfile_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal do_write     : std_logic := '0';
    signal addr_write   : ro2_address := (others => '0');
    signal data_in      : ro2_word := (others => '0');
    signal addrA        : ro2_address := (others => '0');
    signal addrB        : ro2_address := (others => '0');
    signal A_out        : ro2_word;
    signal B_out        : ro2_word;

begin

    dut: entity work.regfile(rtl)
        port map (
            clock_in      => clk,
            reset_in      => reset,
            do_write_in   => do_write,
            addr_write_in => addr_write,
            data_in       => data_in,
            addrA_in      => addrA,
            addrB_in      => addrB,
            A_out         => A_out,
            B_out         => B_out
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim: process
    begin

        -- After reset every register reads as zero
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';
        addrA <= x"0";
        addrB <= x"1";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"00" report "Reset: s0 should be 0" severity error;
        assert B_out = x"00" report "Reset: s1 should be 0" severity error;

        -- Write s0 = 0xAA, read back on port A
        do_write   <= '1';
        addr_write <= x"0";
        data_in    <= x"AA";
        addrA      <= x"0";
        wait until rising_edge(clk);
        do_write <= '0';
        wait until rising_edge(clk);  -- read latches one cycle later
        wait for 1 ns;
        assert A_out = x"AA" report "Write/read: s0 should be 0xAA" severity error;

        -- Write s1 = 0x55, read back on port B
        do_write   <= '1';
        addr_write <= x"1";
        data_in    <= x"55";
        addrB      <= x"1";
        wait until rising_edge(clk);
        do_write <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert B_out = x"55" report "Write/read: s1 should be 0x55" severity error;

        -- Simultaneous read: A=s0, B=s1
        addrA <= x"0";
        addrB <= x"1";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"AA" report "Dual read: A (s0) should be 0xAA" severity error;
        assert B_out = x"55" report "Dual read: B (s1) should be 0x55" severity error;

        -- Write protection: do_write=0 must not change register
        do_write   <= '0';
        addr_write <= x"0";
        data_in    <= x"FF";
        wait until rising_edge(clk);
        addrA <= x"0";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"AA" report "Write protect: s0 should still be 0xAA" severity error;

        -- Overwrite s0 with a new value
        do_write   <= '1';
        addr_write <= x"0";
        data_in    <= x"42";
        addrA      <= x"0";
        wait until rising_edge(clk);
        do_write <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"42" report "Overwrite: s0 should be 0x42" severity error;

        -- Writing s2 must not affect s0 or s1
        do_write   <= '1';
        addr_write <= x"2";
        data_in    <= x"BB";
        wait until rising_edge(clk);
        do_write <= '0';
        addrA <= x"0";
        addrB <= x"1";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"42" report "Isolation: s0 should still be 0x42" severity error;
        assert B_out = x"55" report "Isolation: s1 should still be 0x55" severity error;

        -- Sweep all 16 registers: write unique value, read back
        for i in 0 to 15 loop
            do_write   <= '1';
            addr_write <= std_logic_vector(to_unsigned(i, 4));
            data_in    <= std_logic_vector(to_unsigned(i * 16 + i, 8)); -- 0x00, 0x11, 0x22, ...
            wait until rising_edge(clk);
        end loop;
        do_write <= '0';

        for i in 0 to 15 loop
            addrA <= std_logic_vector(to_unsigned(i, 4));
            wait until rising_edge(clk);
            wait for 1 ns;
            assert A_out = std_logic_vector(to_unsigned(i * 16 + i, 8))
                report "All regs: s" & integer'image(i) & " mismatch" severity error;
        end loop;

        -- Read-first: write and read same address in same cycle returns OLD value
        do_write   <= '1';
        addr_write <= x"5";
        data_in    <= x"CC";
        addrA      <= x"5";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"55" report "Read-first: should return old value 0x55" severity error;
        do_write <= '0';
        -- New value visible next cycle
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"CC" report "Read-first: next cycle should return 0xCC" severity error;

        -- Reset clears everything
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';
        addrA <= x"0";
        addrB <= x"F";
        wait until rising_edge(clk);
        wait for 1 ns;
        assert A_out = x"00" report "Reset clear: s0 should be 0" severity error;
        assert B_out = x"00" report "Reset clear: sF should be 0" severity error;

        report "All register file tests passed." severity note;
        stop;
        wait;
    end process;

end architecture;
