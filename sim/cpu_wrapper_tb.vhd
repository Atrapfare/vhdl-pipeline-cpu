----------------------------------------------------------------------------------
-- CPU Simulation Wrapper -- minimal harness for waveform analysis
--
-- Just instantiates the CPU with a clock and one reset pulse.
-- No assertions -- use this to inspect signals in a waveform viewer.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.io_types_pkg.all;

entity cpu_wrapper is
end entity;

architecture sim of cpu_wrapper is
    constant CLK_PERIOD : time := 5 ns;

    signal clock_s      : std_logic := '0';
    signal reset        : std_logic := '0';
    signal port_id      : std_logic_vector(7 downto 0) := (others => '0');
    signal in_port      : std_logic_vector(7 downto 0) := (others => '0');
    signal out_port     : std_logic_vector(7 downto 0) := (others => '0');
    signal write_strobe : std_logic := '0';
    signal read_strobe  : std_logic := '0';

    component cpu_top is
        Port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            port_id      : out std_logic_vector(7 downto 0);
            in_port      : in  std_logic_vector(7 downto 0);
            out_port     : out std_logic_vector(7 downto 0);
            write_strobe : out std_logic;
            read_strobe  : out std_logic
        );
    end component;

begin

    uut: cpu_top port map (
        clk          => clock_s,
        reset        => reset,
        port_id      => port_id,
        in_port      => in_port,
        out_port     => out_port,
        write_strobe => write_strobe,
        read_strobe  => read_strobe
    );

    clock_s <= not clock_s after CLK_PERIOD / 2;

    -- Single reset pulse at startup
    process
    begin
        reset <= '1';
        wait until rising_edge(clock_s);
        reset <= '0';
        wait;
    end process;

end architecture;

configuration cpu_wrapper_cfg of cpu_wrapper is
    for sim
        for uut: cpu_top
            use entity work.cpu_top(rtl);
            for rtl
                for inner: cpu
                    use entity work.cpu(rtl);
                    for rtl
                        for rom: InstructionMemory
                            use entity work.InstructionMemory(Behavioral);
                        end for;
                    end for;
                end for;
            end for;
        end for;
    end for;
end configuration;
