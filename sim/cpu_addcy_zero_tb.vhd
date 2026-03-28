----------------------------------------------------------------------------------
-- CPU ADDCY zero flag test which checks that ADDCY chains the zero flag
-- through z_i. ADD+ADDCY both producing zero should keep z=1,
-- ADD producing nonzero then ADDCY producing zero should give z=0.
-- Canary 0xEE on port 7 catches wrong branches.
--
--   0: LOAD sF, 0xEE         canary
--   1: LOAD s0, 0xFF
--   2: LOAD s1, 0x00
--   3: ADD  s0, 0x01         0xFF+0x01=0x00, c=1, z=1
--   4: ADDCY s1, 0xFF        0x00+0xFF+1=0x00, c=1, z_i=1 so z=1
--   5: JZ 9                  taken
--   6: OUTPUT sF, 0x07       canary (flushed)
--   7: NOP
--   8: NOP
--   9: LOAD sA, 0xAA
--  10: OUTPUT sA, 0x00       port 0 = 0xAA
--  11: LOAD s2, 0x01
--  12: LOAD s3, 0x03
--  13: ADD  s2, 0x01         0x01+0x01=0x02, c=0, z=0
--  14: ADDCY s3, 0xFD        0x03+0xFD+0=0x00, c=1, z_i=0 so z=0
--  15: JNZ 19                taken
--  16: OUTPUT sF, 0x07       canary (flushed)
--  17: NOP
--  18: NOP
--  19: LOAD sB, 0xBB
--  20: OUTPUT sB, 0x01       port 1 = 0xBB
--  21: JUMP 21
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity cpu_addcy_zero_tb is
end entity;

architecture sim of cpu_addcy_zero_tb is

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
        variable saw_p0 : boolean := false;
        variable saw_p1 : boolean := false;
        constant MAX_CYCLES : integer := 100;
    begin
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';

        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- Canary
            assert out_ports(7) /= x"EE"
                report "FAIL: canary 0xEE on port 7, wrong branch taken"
                severity failure;

            if out_ports(0) = x"AA" and not saw_p0 then
                saw_p0 := true;
                report "ADDCY z_i=1: port 0 = 0xAA (JZ taken)" severity note;
            end if;

            if out_ports(1) = x"BB" and not saw_p1 then
                saw_p1 := true;
                report "ADDCY z_i=0: port 1 = 0xBB (JNZ taken)" severity note;
            end if;

            if saw_p0 and saw_p1 then
                report "ADDCY zero flag tests passed" severity note;
                wait;
            end if;
        end loop;

        assert saw_p0 report "TIMEOUT: port 0 never 0xAA (z_i=1 test)" severity failure;
        assert saw_p1 report "TIMEOUT: port 1 never 0xBB (z_i=0 test)" severity failure;
        wait;
    end process;

end architecture;

-- Custom ROM
architecture AddcyZeroTest of InstructionMemory is

    type rom_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    constant ROM : rom_type := (
        0  => "010101111111101110",  -- LOAD sF, 0xEE (canary)
        1  => "010101000011111111",  -- LOAD s0, 0xFF
        2  => "010101000100000000",  -- LOAD s1, 0x00
        3  => "000011000000000001",  -- ADD  s0, 0x01  (0xFF+0x01=0x00, c=1, z=1)
        4  => "000101000111111111",  -- ADDCY s1, 0xFF (0x00+0xFF+1=0x00, c=1, z_i=1 → z=1)
        5  => "110001000000001001",  -- JZ 9            (z=1, taken)
        6  => "011001111100000111",  -- OUTPUT sF, 0x07 (canary, flushed)
        7  => "000000000000000000",  -- NOP
        8  => "000000000000000000",  -- NOP
        9  => "010101101010101010",  -- LOAD sA, 0xAA
        10 => "011001101000000000",  -- OUTPUT sA, 0x00 (port 0 = 0xAA, test 1 passed)
        11 => "010101001000000001",  -- LOAD s2, 0x01
        12 => "010101001100000011",  -- LOAD s3, 0x03
        13 => "000011001000000001",  -- ADD  s2, 0x01  (0x01+0x01=0x02, c=0, z=0)
        14 => "000101001111111101",  -- ADDCY s3, 0xFD (0x03+0xFD+0=0x00, c=1, z_i=0 → z=0)
        15 => "110010000000010011",  -- JNZ 19          (z=0, taken)
        16 => "011001111100000111",  -- OUTPUT sF, 0x07 (canary, flushed)
        17 => "000000000000000000",  -- NOP
        18 => "000000000000000000",  -- NOP
        19 => "010101101110111011",  -- LOAD sB, 0xBB
        20 => "011001101100000001",  -- OUTPUT sB, 0x01 (port 1 = 0xBB, test 2 passed)
        21 => "110000000000010101",  -- JUMP 21

        others => (others => '0')
    );

begin
    Instruction <= ROM(to_integer(unsigned(Address)));
end AddcyZeroTest;

configuration cpu_addcy_zero_tb_cfg of cpu_addcy_zero_tb is
    for sim
        for uut: cpu
            use entity work.cpu(rtl);
            for rtl
                for rom: InstructionMemory
                    use entity work.InstructionMemory(AddcyZeroTest);
                end for;
            end for;
        end for;
    end for;
end configuration;
