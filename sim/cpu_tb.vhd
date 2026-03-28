----------------------------------------------------------------------------------
-- CPU Integration Testbench -- Fibonacci output verification
--
-- Runs the boot ROM Fibonacci program and watches port 0 for value
-- transitions: 0->1, 1->2, 2->3, 3->5. Uses transition detection
-- because the first two outputs (1, 1) look identical from outside.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;
use std.env.all;

entity cpu_tb is
end entity;

architecture sim of cpu_tb is

    constant CLK_PERIOD : time := 10 ns;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal in_ports  : port_array := (others => (others => '0'));
    signal out_ports : port_array;

    component cpu is
        Port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            in_ports  : in  port_array;
            out_ports : out port_array
        );
    end component;

    -- Expected distinct transitions on port 0 (second fib(1)=1 is indistinguishable)
    type fib_transitions_t is array (0 to 3) of std_logic_vector(7 downto 0);
    constant EXPECTED_TRANSITIONS : fib_transitions_t := (x"01", x"02", x"03", x"05");

begin

    uut: cpu port map (
        clk       => clk,
        reset     => reset,
        in_ports  => in_ports,
        out_ports => out_ports
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

    -- Watch port 0 for each Fibonacci value change
    test_process: process
        variable trans_index : integer := 0;
        variable prev_value  : std_logic_vector(7 downto 0) := x"00";
        variable timeout     : integer := 0;
        constant MAX_CYCLES  : integer := 500;
    begin
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';

        while trans_index < 4 loop
            wait until rising_edge(clk);
            timeout := timeout + 1;

            if timeout > MAX_CYCLES then
                report "TIMEOUT: only captured " & integer'image(trans_index)
                     & " of 4 transitions after " & integer'image(MAX_CYCLES) & " cycles"
                    severity failure;
            end if;

            -- Detect a value change on port 0
            if out_ports(0) /= prev_value then
                assert out_ports(0) = EXPECTED_TRANSITIONS(trans_index)
                    report "Fibonacci transition " & integer'image(trans_index)
                         & ": expected " & integer'image(to_integer(unsigned(EXPECTED_TRANSITIONS(trans_index))))
                         & " but got " & integer'image(to_integer(unsigned(out_ports(0))))
                    severity error;

                report "Fibonacci transition " & integer'image(trans_index)
                     & ": port 0 = " & integer'image(to_integer(unsigned(out_ports(0))))
                    severity note;

                prev_value := out_ports(0);
                trans_index := trans_index + 1;
            end if;
        end loop;

        -- Final value should be 5
        assert out_ports(0) = x"05"
            report "Final port value should be 5"
            severity error;

        wait for CLK_PERIOD * 20;

        report "CPU integration test passed: Fibonacci sequence verified" severity note;
        wait;
    end process;

end architecture;

-- Bind the default boot ROM for this testbench
configuration cpu_tb_cfg of cpu_tb is
    for sim
        for uut: cpu
            use entity work.cpu(rtl);
            for rtl
                for rom: InstructionMemory
                    use entity work.InstructionMemory(Behavioral);
                end for;
            end for;
        end for;
    end for;
end configuration;
