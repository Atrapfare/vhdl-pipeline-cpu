----------------------------------------------------------------------------------
-- Datapath Testbench -- verifies register-ALU pipeline behaviour
--
-- Covers: data passthrough, LOAD via PASS_B + constant, register read-back,
-- register-to-register copy, COMPARE (SUB with flag_write), flag
-- preservation across NOPs, and stall bubble insertion.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common.all;
use work.alu_pkg.all;
use std.env.all;

entity datapath_tb is
end entity;

architecture sim of datapath_tb is

    constant clock_period: time := 5 ns;

    signal cycle_counter_s: unsigned(8 downto 0) := (others => '0');
    signal clock_s: std_logic := '0';
    signal reset_s: std_logic := '0';
    signal flush_s: std_logic := '0';

    signal op_s: alu_op_t := ALU_NOP;
    signal addrA_s: ro2_address := (others => '0');
    signal addrB_s: ro2_address := (others => '0');
    signal const_s: ro2_word := (others => '0');
    signal use_const_s: std_logic := '0';
    signal data_in_s: ro2_word := (others => '0');
    signal use_data_in_s: std_logic := '0';
    signal do_write_s: std_logic := '0';
    signal flag_write_s: std_logic := '0';
    signal stall_s: std_logic := '0';
    signal data_out_s: ro2_word := (others => '0');
    signal addr_out_s: ro2_word := (others => '0');
    signal carry_flag_s: std_logic := '0';
    signal zero_flag_s: std_logic := '0';
    signal write_addr_out_s: ro2_address := (others => '0');
    signal write_enable_out_s: std_logic := '0';

begin

    uut: entity work.datapath port map (
        clock_in => clock_s,
        reset_in => reset_s,
        stall_in => stall_s,
        flush_in => flush_s,
        op_in => op_s,
        addrA_in => addrA_s,
        addrB_in => addrB_s,
        const_in => const_s,
        use_const_in => use_const_s,
        data_in => data_in_s,
        use_data_in => use_data_in_s,
        do_write_in => do_write_s,
        flag_write_in => flag_write_s,
        address_out => addr_out_s,
        data_out => data_out_s,
        carry_flag_out => carry_flag_s,
        zero_flag_out => zero_flag_s,
        write_addr_out => write_addr_out_s,
        write_enable_out => write_enable_out_s
    );

    clock_process: process
    begin
        clock_s <= '0';
        wait for clock_period / 2;
        clock_s <= '1';
        wait for clock_period / 2;
    end process;

    -- Visible cycle counter for waveform debugging
    clock_vis_process: process(clock_s)
    begin
        if rising_edge(clock_s) then
            cycle_counter_s <= cycle_counter_s + 1;
        end if;
    end process;

    stimuli: process

        -- assert data_out and flag values
        -- Warning: Delays until next falling_edge!
        procedure assert_current (
            constant result: ro2_word;
            constant carry: std_logic;
            constant zero: std_logic
        ) is
        begin

            -- ensure signals are stable
            wait until falling_edge(clock_s);

            assert result = data_out_s
                report "expected result=" & integer'image(to_integer(unsigned(result))) & " but got=" & integer'image(to_integer(unsigned(data_out_s))) & " at cycle " & integer'image(to_integer(cycle_counter_s))
                severity error;

            assert carry = carry_flag_s
                report "expected carry=" & std_logic'image(carry) & " but got=" & std_logic'image(carry_flag_s) & " at cycle " & integer'image(to_integer(cycle_counter_s))
                severity error;

            assert zero = zero_flag_s
                report "expected zero=" & std_logic'image(zero) & " but got=" & std_logic'image(zero_flag_s) & " at cycle " & integer'image(to_integer(cycle_counter_s))
                severity error;
        end procedure;
        
        -- assert data_out and flag values
        procedure assert_reg (
            constant reg: ro2_address;
            constant result: ro2_word;
            constant carry: std_logic;
            constant zero: std_logic
        ) is
        begin
        
            -- read reg value
            op_s <= ALU_NOP;
            addrA_s <= reg;
            wait until rising_edge(clock_s);
            
            assert_current(result, carry, zero);
            wait until rising_edge(clock_s);
        
        end procedure;
        
        procedure stall is
        begin
        
            stall_s <= '1';
            wait until rising_edge(clock_s);
            stall_s <= '0';
        
        end procedure;

    begin
        reset_s <= '1';
    
        -- Flags start at 0
        assert_current((others => '0'), '0', '0');

        wait until rising_edge(clock_s);
        reset_s <= '0';
        
        
        -- Read s0 (should still be 0)
        assert_reg(x"0", "00000000", '0', '0');


        -- LOAD s0 = 0x55 (use PASS_B with const)
        op_s <= ALU_PASS_B;
        flag_write_s <= '0';
        addrA_s <= "0000";
        use_const_s <= '1';
        const_s <= "01010101";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        const_s <= "00000000";
        use_const_s <= '0';
        do_write_s <= '0';
        
        stall;
        assert_reg(x"0", "01010101", '0', '0');


        -- Read s1 (should still be 0)
        assert_reg(x"1", "00000000", '0', '0');


        -- Copy s0 to s1: s1 = PASS_B(s0)
        op_s <= ALU_PASS_B;
        flag_write_s <= '0';
        addrA_s <= "0001";
        use_const_s <= '0';
        addrB_s <= "0000";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        
        stall;
        assert_reg(x"1", "01010101", '0', '0');


        -- COMPARE s0, s1: SUB with flag_write
        -- s0=0x55, s1=0x55 => result=0x00, carry=0, zero=1
        op_s <= ALU_SUB;
        flag_write_s <= '1';
        addrA_s <= "0000";
        addrB_s <= "0001";
        use_const_s <= '0';
        const_s <= "11111111";
        wait until rising_edge(clock_s);
        flag_write_s <= '0';
        
        stall;
        assert_reg(x"0", "01010101", '0', '1');
        assert_reg(x"1", "01010101", '0', '1');


        -- s1 = s1 + 1 => s1 becomes 0x56
        op_s <= ALU_ADD;
        flag_write_s <= '1';
        addrA_s <= "0001";
        use_const_s <= '1';
        const_s <= "00000001";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        flag_write_s <= '0';
        
        stall;
        assert_reg(x"0", "01010101", '0', '0');
        assert_reg(x"1", "01010110", '0', '0');


        -- COMPARE s0, s1: s0=0x55, s1=0x56 => 0x55-0x56=0xFF, carry=1
        op_s <= ALU_SUB;
        flag_write_s <= '1';
        addrA_s <= "0000";
        addrB_s <= "0001";
        use_const_s <= '0';
        const_s <= "11111111";
        wait until rising_edge(clock_s);
        flag_write_s <= '0';
        
        stall;
        assert_reg(x"0", "01010101", '1', '0');
        assert_reg(x"1", "01010110", '1', '0');


        -- COMPARE s1, s0: s1=0x56, s0=0x55 => 0x56-0x55=0x01, carry=0
        op_s <= ALU_SUB;
        flag_write_s <= '1';
        addrA_s <= "0001";
        addrB_s <= "0000";
        use_const_s <= '0';
        const_s <= "11111111";
        wait until rising_edge(clock_s);
        flag_write_s <= '0';
        
        stall;
        assert_reg(x"0", "01010101", '0', '0');
        assert_reg(x"1", "01010110", '0', '0');


        assert_reg(x"2", "00000000", '0', '0');

        -- Flag preservation: flags must survive NOPs with flag_write=0
        -- First set carry+zero via 0xFF+0x01=0x00
        wait until rising_edge(clock_s);
        op_s <= ALU_PASS_B;
        flag_write_s <= '0';
        addrA_s <= "0010";
        use_const_s <= '1';
        const_s <= "11111111";
        do_write_s <= '1';

        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';

        op_s <= ALU_NOP;
        flag_write_s <= '0';
        wait until rising_edge(clock_s);

        -- s2=0xFF, now ADD s2, 0x01 -> overflow, carry=1, zero=1
        op_s <= ALU_ADD;
        flag_write_s <= '1';
        addrA_s <= "0010";
        use_const_s <= '1';
        const_s <= "00000001";
        do_write_s <= '1';

        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';
        flag_write_s <= '0';
        
        stall;
        assert_reg("0010", x"00", '1', '1');

        -- NOP with flag_write=0: flags must hold
        op_s <= ALU_NOP;
        flag_write_s <= '0';
        wait until rising_edge(clock_s);
        assert_reg("0010", x"00", '1', '1');

        -- Stall: still preserved
        stall;
        assert_reg("0010", x"00", '1', '1');


        -- Stall bubble: pipeline must suppress write during stall
        op_s <= ALU_PASS_B;
        flag_write_s <= '0';
        addrA_s <= "0011";
        use_const_s <= '1';
        const_s <= "10101010";
        do_write_s <= '1';

        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';

        -- Write signals should be active after the PASS_B
        wait for clock_period / 4;
        assert write_enable_out_s = '1'
            report "Stall test: expected write_enable_out=1" severity error;
        assert write_addr_out_s = "0011"
            report "Stall test: expected write_addr_out=0011" severity error;

        -- Assert stall: pipeline bubble suppresses write
        stall_s <= '1';
        op_s <= ALU_ADD;
        flag_write_s <= '1';
        addrA_s <= "0011";
        do_write_s <= '1';

        wait until rising_edge(clock_s);
        wait for clock_period / 4;
        assert write_enable_out_s = '0'
            report "Stall test: expected write_enable_out=0 during stall bubble" severity error;

        -- Release stall
        stall_s <= '0';
        wait until rising_edge(clock_s);
        wait for clock_period / 4;

        report "Stall test passed" severity note;
        
        
        -- Test data_in
        reset_s <= '1';
        flag_write_s <= '0';
        wait until rising_edge(clock_s);
        reset_s <= '0';
        
        -- sA = 0xAB
        op_s <= ALU_PASS_B;
        addrA_s <= x"A";
        use_const_s <= '1';
        const_s <= x"BC";
        data_in_s <= x"FF";
        use_data_in_s <= '0';
        wait until rising_edge(clock_s);
        use_const_s <= '0';
        const_s <= x"00";
        
        stall;
        assert_reg(x"A", x"BC", '0', '0');
        
        -- data_in overwrites alu
        op_s <= ALU_PASS_B;
        addrA_s <= x"A";
        use_data_in_s <= '1';
        wait until rising_edge(clock_s);
        use_data_in_s <= '0';
        
        stall;
        assert_reg(x"A", x"FF", '0', '0');


        -- z_i propagation test
        -- set carry=1, zero=1 via 0xFF + 0x01 = 0x00
        op_s <= ALU_ADD;
        flag_write_s <= '1';
        addrA_s <= "0100";
        use_const_s <= '1';
        const_s <= x"FF";
        do_write_s <= '1';
        wait until rising_edge(clock_s);

        -- NOP gap
        do_write_s <= '0';
        use_const_s <= '0';
        flag_write_s <= '0';
        op_s <= ALU_NOP;
        wait until rising_edge(clock_s);
        wait until rising_edge(clock_s);

        -- LOAD s4 = 0xFF
        op_s <= ALU_PASS_B;
        flag_write_s <= '0';
        addrA_s <= "0100";
        use_const_s <= '1';
        const_s <= x"FF";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';
        op_s <= ALU_NOP;
        wait until rising_edge(clock_s);

        -- ADD s4, 0x01 => 0xFF+0x01=0x00, carry=1, zero=1
        op_s <= ALU_ADD;
        flag_write_s <= '1';
        addrA_s <= "0100";
        use_const_s <= '1';
        const_s <= x"01";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';

        -- check forwarded flags
        wait for clock_period / 4;
        assert carry_flag_s = '1'
            report "z_i test: expected carry=1 after 0xFF+0x01" severity error;
        assert zero_flag_s = '1'
            report "z_i test: expected zero=1 after 0xFF+0x01" severity error;

        -- NOP gap (avoid RAW on s4)
        op_s <= ALU_NOP;
        flag_write_s <= '0';
        wait until rising_edge(clock_s);

        -- ADDCY s4, 0xFF => 0x00+0xFF+1=0x00, z_i=1 => zero=1
        op_s <= ALU_ADDCY;
        flag_write_s <= '1';
        addrA_s <= "0100";
        use_const_s <= '1';
        const_s <= x"FF";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';

        wait for clock_period / 4;
        assert carry_flag_s = '1'
            report "z_i test: expected carry=1 after ADDCY" severity error;
        assert zero_flag_s = '1'
            report "z_i test: expected zero=1 (z_i=1 propagated)" severity error;

        -- clear zero flag with nonzero ADD, NOP gap first
        op_s <= ALU_NOP;
        flag_write_s <= '0';
        wait until rising_edge(clock_s);

        op_s <= ALU_ADD;
        flag_write_s <= '1';
        addrA_s <= "0100";
        use_const_s <= '1';
        const_s <= x"01";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';

        wait for clock_period / 4;
        assert zero_flag_s = '0'
            report "z_i test: expected zero=0 after nonzero ADD" severity error;

        -- NOP gap
        op_s <= ALU_NOP;
        flag_write_s <= '0';
        wait until rising_edge(clock_s);

        -- ADDCY s4, 0xFF => 0x01+0xFF+0=0x00, z_i=0 => zero=0
        op_s <= ALU_ADDCY;
        flag_write_s <= '1';
        addrA_s <= "0100";
        use_const_s <= '1';
        const_s <= x"FF";
        do_write_s <= '1';
        wait until rising_edge(clock_s);
        do_write_s <= '0';
        use_const_s <= '0';

        wait for clock_period / 4;
        assert zero_flag_s = '0'
            report "z_i test: expected zero=0 (z_i=0 blocks it)" severity error;

        report "z_i propagation test passed" severity note;

        -- End of tests
        report "Datapath tests passed" severity note;
        wait;
    end process;

end architecture;
