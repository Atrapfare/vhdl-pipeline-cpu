----------------------------------------------------------------------------------
-- Datapath Flush Testbench -- flush and data_in writeback behaviour
--
-- Tests: flush inserting a pipeline bubble, data_in writeback path,
-- data_in priority over ALU result, and flags surviving a flush.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common.all;
use work.alu_pkg.all;

entity datapath_flush_tb is
end entity;

architecture sim of datapath_flush_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk            : std_logic := '0';
    signal reset          : std_logic := '0';
    signal flush          : std_logic := '0';
    signal stall          : std_logic := '0';
    signal op             : alu_op_t := ALU_NOP;
    signal addrA          : ro2_address := (others => '0');
    signal addrB          : ro2_address := (others => '0');
    signal const_val      : ro2_word := (others => '0');
    signal use_const      : std_logic := '0';
    signal data_in        : ro2_word := (others => '0');
    signal use_data_in    : std_logic := '0';
    signal do_write       : std_logic := '0';
    signal flag_write     : std_logic := '0';
    signal address_out    : ro2_word;
    signal data_out       : ro2_word;
    signal carry_flag     : std_logic;
    signal zero_flag      : std_logic;
    signal write_addr_out : ro2_address;
    signal write_enable   : std_logic;

begin

    uut: entity work.datapath port map (
        clock_in         => clk,
        reset_in         => reset,
        stall_in         => stall,
        flush_in         => flush,
        op_in            => op,
        addrA_in         => addrA,
        addrB_in         => addrB,
        const_in         => const_val,
        use_const_in     => use_const,
        data_in          => data_in,
        use_data_in      => use_data_in,
        do_write_in      => do_write,
        flag_write_in    => flag_write,
        address_out      => address_out,
        data_out         => data_out,
        carry_flag_out   => carry_flag,
        zero_flag_out    => zero_flag,
        write_addr_out   => write_addr_out,
        write_enable_out => write_enable
    );

    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    test_process: process
    begin
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        -- Flush inserts a pipeline bubble (write_enable goes low)
        op <= ALU_ADD;
        flag_write <= '1';
        addrA <= "0000";
        use_const <= '1';
        const_val <= x"01";
        do_write <= '1';

        wait until rising_edge(clk);

        -- ADD is now in the execute stage
        wait for CLK_PERIOD / 4;
        assert write_enable = '1'
            report "flush: write_enable should be 1 before flush" severity error;

        -- Flush: pipeline should drop the in-flight instruction
        flush <= '1';
        op <= ALU_ADD;
        flag_write <= '1';
        do_write <= '1';

        wait until rising_edge(clk);
        flush <= '0';
        op <= ALU_NOP;
        flag_write <= '0';
        do_write <= '0';

        wait for CLK_PERIOD / 4;
        assert write_enable = '0'
            report "flush: write_enable should be 0 after flush" severity error;

        report "flush test passed" severity note;

        -- data_in writeback: external data (IO/memory) written to register
        wait until rising_edge(clk);

        -- Write 0xBE to s5 via data_in path
        op <= ALU_NOP;
        flag_write <= '0';
        addrA <= "0101";
        do_write <= '1';
        use_data_in <= '1';
        data_in <= x"BE";

        wait until rising_edge(clk);
        do_write <= '0';
        use_data_in <= '0';

        wait until rising_edge(clk);
        data_in <= (others => '0');

        -- Read s5 back
        op <= ALU_NOP;
        addrA <= "0101";

        wait until rising_edge(clk);
        wait for CLK_PERIOD / 4;

        assert data_out = x"BE"
            report "data_in writeback: expected s5=0xBE, got " &
                integer'image(to_integer(unsigned(data_out)))
            severity error;

        report "data_in writeback test passed" severity note;

        -- data_in has priority over ALU result
        wait until rising_edge(clk);

        -- Decode ADD s5, 0x01 but use_data_in=1 with data_in=0x77
        -- Writeback should be 0x77, not 0xBF (0xBE+0x01)
        op <= ALU_ADD;
        flag_write <= '0';
        addrA <= "0101";
        use_const <= '1';
        const_val <= x"01";
        do_write <= '1';
        use_data_in <= '1';
        data_in <= x"77";

        wait until rising_edge(clk);
        do_write <= '0';
        use_data_in <= '0';
        use_const <= '0';

        wait until rising_edge(clk);
        data_in <= (others => '0');

        -- Read s5
        op <= ALU_NOP;
        addrA <= "0101";

        wait until rising_edge(clk);
        wait for CLK_PERIOD / 4;

        assert data_out = x"77"
            report "data_in priority: expected s5=0x77, got " &
                integer'image(to_integer(unsigned(data_out)))
            severity error;

        report "data_in priority test passed" severity note;

        -- Flush clears pipeline but preserves flag registers
        wait until rising_edge(clk);

        -- Write 0xFF to s6
        op <= ALU_PASS_B;
        flag_write <= '0';
        addrA <= "0110";
        use_const <= '1';
        const_val <= x"FF";
        do_write <= '1';

        wait until rising_edge(clk);
        do_write <= '0';
        use_const <= '0';

        op <= ALU_NOP;
        wait until rising_edge(clk);

        -- ADD s6, 0x02 -> 0xFF+0x02=0x01, carry=1
        op <= ALU_ADD;
        flag_write <= '1';
        addrA <= "0110";
        use_const <= '1';
        const_val <= x"02";
        do_write <= '1';

        wait until rising_edge(clk);
        do_write <= '0';
        use_const <= '0';

        wait for CLK_PERIOD / 4;
        assert carry_flag = '1'
            report "flush flags: carry should be 1 after overflow" severity error;

        -- Flush: carry must survive
        flush <= '1';
        op <= ALU_NOP;
        flag_write <= '0';

        wait until rising_edge(clk);
        flush <= '0';

        wait for CLK_PERIOD / 4;
        assert carry_flag = '1'
            report "flush flags: carry should stay 1 after flush" severity error;

        report "flush flags test passed" severity note;

        report "datapath tests passed" severity note;
        wait;
    end process;

end architecture;
