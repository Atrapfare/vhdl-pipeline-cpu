----------------------------------------------------------------------------------
-- IO Unit Testbench -- read/write, port isolation, boundary, simultaneous
--
-- Sweeps all ports for input read and output write, checks that non-addressed
-- ports are not disturbed, verifies write protection (io_wr=0), tests
-- simultaneous read+write, and exercises boundary ports (0 and highest).
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity IO_Unit_TB is
end IO_Unit_TB;

architecture tb of IO_Unit_TB is

    constant CLK_PERIOD : time := 20 ns;           -- 50 MHz
    constant NUM_PORTS  : integer := port_array'length;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';

    signal io_rd        : std_logic := '0';
    signal io_wr        : std_logic := '0';
    signal port_pp      : std_logic_vector(7 downto 0) := (others => '0');

    signal cpu_data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal io_data_out  : std_logic_vector(7 downto 0);

    signal in_ports     : port_array := (others => (others => '0'));
    signal out_ports    : port_array;

begin

    uut : entity work.IO_Unit
        port map (
            clk          => clk,
            rst          => rst,
            io_rd        => io_rd,
            io_wr        => io_wr,
            port_pp      => port_pp,
            cpu_data_in  => cpu_data_in,
            io_data_out  => io_data_out,
            in_ports     => in_ports,
            out_ports    => out_ports
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
        variable test_value : std_logic_vector(7 downto 0);
        variable old_ports  : port_array;
        type idx_array is array (0 to 1) of integer;
        constant boundary_ports : idx_array := (0, NUM_PORTS-1);
    begin

        -- Reset: all output ports should be zero
        rst <= '1';
        wait for 2 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        for i in 0 to NUM_PORTS-1 loop
            assert out_ports(i) = x"00"
                report "ERROR: Output not reset on port " & integer'image(i)
                severity error;
        end loop;

        -- Read sweep: check every input port, and verify io_data_out goes
        -- back to zero when io_rd is de-asserted
        for i in 0 to NUM_PORTS-1 loop
            test_value := std_logic_vector(to_unsigned(i, 8));
            in_ports(i) <= test_value;
            port_pp <= std_logic_vector(to_unsigned(i, 8));
            io_rd   <= '1';
            wait for 1 ns;
            assert io_data_out = test_value
                report "ERROR: Input read failed on port " & integer'image(i)
                severity error;
            io_rd <= '0';
            wait for 1 ns;
            assert io_data_out = x"00"
                report "ERROR: io_data_out not zero when io_rd = 0 (port " & integer'image(i) & ")"
                severity error;
        end loop;

        -- Write sweep: write each output port, verify isolation (other ports
        -- unchanged), write protection (io_wr=0), and value stability
        for i in 0 to NUM_PORTS-1 loop
            test_value := not std_logic_vector(to_unsigned(i, 8));
            old_ports := out_ports;
            cpu_data_in <= test_value;
            port_pp <= std_logic_vector(to_unsigned(i, 8));
            io_wr <= '1';
            wait until rising_edge(clk);
            io_wr <= '0';
            wait for 1 ns;

            -- Only the addressed port should change
            for j in 0 to NUM_PORTS-1 loop
                if j = i then
                    assert out_ports(j) = test_value
                        report "ERROR: Output write failed on port " & integer'image(j)
                        severity error;
                else
                    assert out_ports(j) = old_ports(j)
                        report "ERROR: Non-addressed port " & integer'image(j) & " modified"
                        severity error;
                end if;
            end loop;

            -- Write protection: io_wr=0 must not change anything
            cpu_data_in <= x"FF";
            io_wr <= '0';
            port_pp <= std_logic_vector(to_unsigned(i, 8));
            wait until rising_edge(clk);
            wait for 1 ns;
            assert out_ports(i) = test_value
                report "ERROR: Output changed with io_wr=0 (port " & integer'image(i) & ")"
                severity error;

            -- Value should hold across several cycles
            wait for 3 * CLK_PERIOD;
            assert out_ports(i) = test_value
                report "ERROR: Output unstable (port " & integer'image(i) & ")"
                severity error;
        end loop;

        -- Simultaneous read and write on port 10
        in_ports(10) <= x"5A";
        port_pp <= x"0A";
        cpu_data_in <= x"A5";
        io_wr <= '1';
        io_rd <= '1';
        wait until rising_edge(clk);
        io_wr <= '0';
        io_rd <= '0';
        wait for 1 ns;
        assert out_ports(10) = x"A5"
            report "Write failed during simultaneous read"
            severity error;
        io_rd <= '1';
        wait for 1 ns;
        assert io_data_out = x"5A"
            report "Read incorrect during simultaneous write"
            severity error;
        io_rd <= '0';
        wait for 1 ns;

        -- Boundary ports: port 0 and highest port
        for k in boundary_ports'range loop
            test_value := not std_logic_vector(to_unsigned(boundary_ports(k), 8));

            old_ports := out_ports;
            cpu_data_in <= test_value;
            port_pp <= std_logic_vector(to_unsigned(boundary_ports(k), 8));
            io_wr <= '1';
            wait until rising_edge(clk);
            io_wr <= '0';
            wait for 1 ns;
            for j in 0 to NUM_PORTS-1 loop
                if j = boundary_ports(k) then
                    assert out_ports(j) = test_value
                        report "ERROR: Boundary write failed on port " & integer'image(j)
                        severity error;
                else
                    assert out_ports(j) = old_ports(j)
                        report "ERROR: Non-addressed port " & integer'image(j) & " modified during boundary test"
                        severity error;
                end if;
            end loop;

            in_ports(boundary_ports(k)) <= test_value;
            port_pp <= std_logic_vector(to_unsigned(boundary_ports(k), 8));
            io_rd <= '1';
            wait for 1 ns;
            assert io_data_out = test_value
                report "ERROR: Boundary read failed on port " & integer'image(boundary_ports(k))
                severity error;
            io_rd <= '0';
            wait for 1 ns;
        end loop;

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;

end tb;
