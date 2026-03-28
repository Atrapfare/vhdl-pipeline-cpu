----------------------------------------------------------------------------------
-- CPU Pipeline Testbench -- back-to-back stalls, stall+branch, reset recovery
--
-- Custom ROM program that exercises:
--   - Two consecutive RAW hazards (ADD s1,s0 then ADD s2,s1)
--   - Stall followed by JC (carry-set branch after overflow)
--   - Stall followed by JNC (no-carry branch)
--   - Mid-execution reset and re-convergence
--
-- Canary value 0xDD must never appear on any observed port.
-- See program listing below.
--
--   0: LOAD sF, 0xDD        canary
--   1: LOAD s0, 0x10
--   2: ADD s1, s0           stall on s0, s1 = 0x10
--   3: ADD s2, s1           stall on s1, s2 = 0x10
--   4: OUTPUT s1, 0x00      port 0 = 0x10
--   5: OUTPUT s2, 0x01      port 1 = 0x10
--   6: LOAD s3, 0xFF
--   7: ADD s3, 0x01         stall on s3, s3 = 0x00, carry=1
--   8: JC 12                taken, flush 9
--   9: OUTPUT sF, 0x02      canary, must NOT execute
--  10: NOP
--  11: NOP
--  12: OUTPUT s3, 0x02      port 2 = 0x00
--  13: LOAD s4, 0x01
--  14: ADD s4, 0x01         stall on s4, s4 = 0x02, carry=0
--  15: JNC 19               taken, flush 16
--  16: OUTPUT sF, 0x03      canary, must NOT execute
--  17: NOP
--  18: NOP
--  19: OUTPUT s4, 0x03      port 3 = 0x02
--  20: JUMP 20
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity cpu_pipeline_tb is
end entity;

architecture sim of cpu_pipeline_tb is

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
        variable cycles     : integer := 0;
        variable saw_p0     : boolean := false;
        variable saw_p1     : boolean := false;
        variable saw_p2     : boolean := false;
        variable saw_p3     : boolean := false;
        constant MAX_CYCLES : integer := 120;
    begin
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';

        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- Canary 0xDD must never appear on any port
            assert out_ports(0) /= x"DD"
                report "FAIL: canary 0xDD on port 0" severity failure;
            assert out_ports(1) /= x"DD"
                report "FAIL: canary 0xDD on port 1" severity failure;
            assert out_ports(2) /= x"DD"
                report "FAIL: canary 0xDD on port 2" severity failure;
            assert out_ports(3) /= x"DD"
                report "FAIL: canary 0xDD on port 3" severity failure;

            -- Back-to-back stall results
            if out_ports(0) = x"10" and not saw_p0 then
                saw_p0 := true;
                report "back-to-back stall: port 0 = 0x10" severity note;
            end if;

            if out_ports(1) = x"10" and not saw_p1 then
                saw_p1 := true;
                report "back-to-back stall: port 1 = 0x10" severity note;
            end if;

            -- Port 2 starts at 0x00, so wait for port 0 first to avoid false match
            if saw_p0 and out_ports(2) = x"00" and not saw_p2 then
                saw_p2 := true;
                report "stall+JC: port 2 = 0x00" severity note;
            end if;

            if out_ports(3) = x"02" and not saw_p3 then
                saw_p3 := true;
                report "stall+JNC: port 3 = 0x02" severity note;
            end if;

            if saw_p0 and saw_p1 and saw_p2 and saw_p3 then
                report "pipeline tests passed" severity note;
                exit;
            end if;
        end loop;

        assert saw_p0 report "TIMEOUT: port 0 never 0x10" severity failure;
        assert saw_p1 report "TIMEOUT: port 1 never 0x10" severity failure;
        assert saw_p2 report "TIMEOUT: port 2 never 0x00" severity failure;
        assert saw_p3 report "TIMEOUT: port 3 never 0x02" severity failure;

        -- Reset mid-execution and verify the program restarts correctly
        wait for CLK_PERIOD * 5;
        reset <= '1';
        wait for CLK_PERIOD * 2;
        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;
        assert out_ports(0) = x"00"
            report "port 0 not cleared after reset" severity error;

        saw_p0 := false;
        cycles := 0;
        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            if out_ports(0) = x"10" and not saw_p0 then
                saw_p0 := true;
                report "reset recovery: port 0 = 0x10" severity note;
                exit;
            end if;
        end loop;

        assert saw_p0 report "TIMEOUT: reset recovery failed" severity failure;

        report "all pipeline and reset tests passed" severity note;
        wait;
    end process;

end architecture;

-- Custom ROM for pipeline stress (see program listing in header)
architecture PipelineTest of InstructionMemory is

    type rom_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    constant ROM : rom_type := (
        -- back-to-back stalls
        0  => "010101111111011101",  -- LOAD sF, 0xDD
        1  => "010101000000010000",  -- LOAD s0, 0x10
        2  => "000010000100000000",  -- ADD s1, s0 (stall on s0)
        3  => "000010001000010000",  -- ADD s2, s1 (stall on s1)
        4  => "011001000100000000",  -- OUTPUT s1, 0x00
        5  => "011001001000000001",  -- OUTPUT s2, 0x01

        -- stall then JC (overflow sets carry)
        6  => "010101001111111111",  -- LOAD s3, 0xFF
        7  => "000011001100000001",  -- ADD s3, 0x01 (stall on s3)
        8  => "110011000000001100",  -- JC 12 (carry=1, taken)
        9  => "011001111100000010",  -- OUTPUT sF, 0x02 (canary, flushed)
        10 => "000000000000000000",  -- NOP
        11 => "000000000000000000",  -- NOP
        12 => "011001001100000010",  -- OUTPUT s3, 0x02

        -- stall then JNC (no carry after small add)
        13 => "010101010000000001",  -- LOAD s4, 0x01
        14 => "000011010000000001",  -- ADD s4, 0x01 (stall on s4)
        15 => "110100000000010011",  -- JNC 19 (carry=0, taken)
        16 => "011001111100000011",  -- OUTPUT sF, 0x03 (canary, flushed)
        17 => "000000000000000000",  -- NOP
        18 => "000000000000000000",  -- NOP
        19 => "011001010000000011",  -- OUTPUT s4, 0x03
        20 => "110000000000010100",  -- JUMP 20

        others => (others => '0')
    );

begin
    Instruction <= ROM(to_integer(unsigned(Address)));
end PipelineTest;

configuration cpu_pipeline_tb_cfg of cpu_pipeline_tb is
    for sim
        for uut: cpu
            use entity work.cpu(rtl);
            for rtl
                for rom: InstructionMemory
                    use entity work.InstructionMemory(PipelineTest);
                end for;
            end for;
        end for;
    end for;
end configuration;
