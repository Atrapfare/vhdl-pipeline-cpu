----------------------------------------------------------------------------------
-- CPU Flush / No-Delay-Slot Testbench
--
-- Verifies that a taken JUMP flushes the next sequential instruction
-- so there is no delay slot. The instruction right after JUMP must
-- never execute.
--
-- Program:
--   0: LOAD s0, 0x11
--   1: LOAD s1, 0x22
--   2: JUMP 0x005
--   3: OUTPUT s0, 0x00   -- must NOT execute (flushed)
--   5: OUTPUT s1, 0x00   -- must execute
--
-- If port 0 ever shows 0x11, the delay-slot instruction leaked through.
-- Correct behaviour: port 0 = 0x22 only.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity cpu_flush_tb is
end entity;

architecture sim of cpu_flush_tb is

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

    test_process: process
        variable cycles : integer := 0;
        constant MAX_CYCLES : integer := 80;
    begin
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';

        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- 0x11 means the flushed OUTPUT leaked through
            assert out_ports(0) /= x"11"
                report "Flush failure: observed delay-slot OUTPUT value 0x11 on port 0"
                severity failure;

            if out_ports(0) = x"22" then
                report "Flush/no-delay-slot test passed (observed only 0x22)" severity note;
                wait;
            end if;
        end loop;

        report "TIMEOUT: never observed expected OUTPUT value 0x22 on port 0" severity failure;
        wait;
    end process;

end architecture;

-- Minimal ROM: LOAD, LOAD, JUMP, flushed OUTPUT, target OUTPUT
architecture FlushTest of InstructionMemory is

    type rom_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    constant ROM : rom_type := (
        0 => "010101000000010001",  -- LOAD s0, 0x11
        1 => "010101000100100010",  -- LOAD s1, 0x22
        2 => "110000000000000101",  -- JUMP 0x005
        3 => "011001000000000000",  -- OUTPUT s0, 0x00  (must NOT execute)
        4 => "000000000000000000",  -- NOP
        5 => "011001000100000000",  -- OUTPUT s1, 0x00  (must execute)
        others => (others => '0')
    );

begin
    Instruction <= ROM(to_integer(unsigned(Address)));
end FlushTest;

configuration cpu_flush_tb_cfg of cpu_flush_tb is
    for sim
        for uut: cpu
            use entity work.cpu(rtl);
            for rtl
                for rom: InstructionMemory
                    use entity work.InstructionMemory(FlushTest);
                end for;
            end for;
        end for;
    end for;
end configuration;
