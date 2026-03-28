----------------------------------------------------------------------------------
-- CPU Stress Testbench -- cold start, Fibonacci, reset recovery, input noise
--
-- Four phases:
--   1. Cold start: reset and verify port 0 is zero
--   2. Fibonacci: wait for output values 1, 2, 3, 5 on port 0
--   3. Reset mid-execution: assert reset, release, verify program restarts
--   4. Input noise: toggle in_ports rapidly, check output stays valid
--
-- Uses the default Fibonacci boot ROM.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity cpu_stress_tb is
end entity;

architecture sim of cpu_stress_tb is

    constant CLK_PERIOD : time := 10 ns;
    constant TIMEOUT    : integer := 5000;

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal in_ports  : port_array := (others => (others => '0'));
    signal out_ports : port_array;

    signal cycle_count : integer := 0;

    component cpu is
        Port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            in_ports  : in  port_array;
            out_ports : out port_array
        );
    end component;

begin

    uut: cpu port map (
        clk       => clk,
        reset     => reset,
        in_ports  => in_ports,
        out_ports => out_ports
    );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        cycle_count <= cycle_count + 1;
        wait for CLK_PERIOD/2;
    end process;

    stim_proc: process

        procedure System_Reset is
        begin
            report "Applying reset...";
            reset <= '1';
            wait for 5 * CLK_PERIOD;
            reset <= '0';
            report "Reset released.";
        end procedure;

        -- Block until port 0 shows the expected value (or timeout)
        procedure Wait_For_Value(val : integer) is
            variable loops : integer := 0;
        begin
            while to_integer(unsigned(out_ports(0))) /= val loop
                wait for CLK_PERIOD;
                loops := loops + 1;
                if loops > TIMEOUT then
                    report "Timeout waiting for value " & integer'image(val)
                           severity failure;
                end if;
            end loop;
            report "Got expected value: " & integer'image(val);
        end procedure;

    begin
        -- Phase 1: cold start
        report "Phase 1: Cold start verification";
        System_Reset;
        wait for 2 * CLK_PERIOD;
        assert to_integer(unsigned(out_ports(0))) = 0
            report "Port 0 not cleared after reset" severity error;

        -- Phase 2: Fibonacci sequence (second 1 not distinguishable by polling)
        report "Phase 2: Fibonacci check (1, 1, 2, 3, 5)";
        Wait_For_Value(1);
        Wait_For_Value(2);
        Wait_For_Value(3);
        Wait_For_Value(5);
        report "Phase 2 passed.";

        -- Phase 3: reset mid-execution, verify program restarts
        report "Phase 3: Reset mid-execution";
        wait for 10 * CLK_PERIOD;
        System_Reset;
        wait for 10 * CLK_PERIOD;
        Wait_For_Value(1);
        report "Phase 3 passed.";

        -- Phase 4: toggle input ports rapidly, outputs must stay defined
        report "Phase 4: Input noise";
        for i in 0 to 10 loop
            in_ports(0) <= std_logic_vector(to_unsigned(i, 8));
            in_ports(1) <= std_logic_vector(to_unsigned(255-i, 8));
            wait for CLK_PERIOD;
        end loop;

        assert not is_x(out_ports(0))
            report "Output port 0 undefined after input noise" severity error;
        report "Phase 4 passed.";

        report "cpu_stress_tb: all tests passed";

        wait;
    end process;

end architecture;

configuration cpu_stress_tb_cfg of cpu_stress_tb is
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
