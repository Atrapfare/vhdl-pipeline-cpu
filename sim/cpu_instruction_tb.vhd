----------------------------------------------------------------------------------
-- CPU Per-Instruction Testbench which exercises individual instruction types
--
-- Custom ROM program that tests: NOP, TEST (reg+imm), conditional jumps
-- (JC, JZ), INPUT, OUTPUT (imm + reg addressed), STORE and FETCH.
-- A canary value (0xEE) on port 6 catches flushed instructions that
-- should never execute. See program listing below.
--
--   0: LOAD sF, 0xEE        canary value
--   1: LOAD s0, 0x42
--   2: NOP
--   3: OUTPUT s0, 0x00      port 0 = 0x42 (NOP preserves s0)
--   4: LOAD s1, 0xFF
--   5: LOAD s2, 0x01
--   6: TEST s1, s2          AND=0x01, parity=odd, carry=1, zero=0
--   7: JC 11                taken, flush 8
--   8: OUTPUT sF, 0x06      canary, must NOT execute
--   9: NOP
--  10: NOP
--  11: OUTPUT s1, 0x01      port 1 = 0xFF (TEST didn't write s1)
--  12: LOAD s3, 0xF0
--  13: TEST s3, 0x0F        AND=0x00, parity=even, carry=0, zero=1
--  14: JZ 18                taken, flush 15
--  15: OUTPUT sF, 0x06      canary, must NOT execute
--  16: NOP
--  17: NOP
--  18: OUTPUT s3, 0x02      port 2 = 0xF0 (TEST didn't write s3)
--  19: INPUT s4, 0x05       read in_ports(5) = 0xAB
--  20: OUTPUT s4, 0x03      port 3 = 0xAB
--  21: LOAD s5, 0x04        port address for OUTPUT_REG
--  22: LOAD s6, 0x99        value
--  23: OUTPUT s6, s5        port 4 = 0x99 (register port address)
--  24: LOAD s7, 0x55
--  25: STORE s7, 0x10       scratchpad[0x10] = 0x55
--  26: NOP
--  27: NOP
--  28: LOAD s8, 0x10        address for FETCH
--  29: FETCH s9, s8         s9 = scratchpad[0x10] = 0x55
--  30: OUTPUT s9, 0x05      port 5 = 0x55
--  31: NOP
--  32: LOAD sA, 0x00
--  33: LOAD sB, 0x01
--  34: SUB sA, sB           carry=1, zero=0
--  35: LOAD sC, 0x03
--  36: LOAD sD, 0x03
--  37: TESTCY sC, sD        parity even, carry chains -> carry=1
--  38: JC 42                taken, flush 39
--  39: OUTPUT sF, 0x06      canary, must NOT execute
--  40: NOP
--  41: NOP
--  42: OUTPUT sC, 0x07      port 7 = 0x03
--  43: LOAD sE, 0xF0
--  44: LOAD s0, 0x0F
--  45: COMPARE sE, sE       zero=1
--  46: TESTCY sE, s0        result=0x00, z_i=1 -> zero=1
--  47: JZ 50                taken, flush 48
--  48: OUTPUT sF, 0x06      canary, must NOT execute
--  49: NOP
--  50: OUTPUT sE, 0x08      port 8 = 0xF0
--  51: LOAD s1, 0x01
--  52: LOAD s2, 0x01
--  53: COMPARE s1, 0x00     carry=0, zero=0 (s1!=0)
--  54: COMPARECY s1, s2     0x01-0x01-0=0x00, but z_i=0 -> zero=0
--  55: JZ 58                NOT taken
--  56: OUTPUT s1, 0x09      port 9 = 0x01
--  57: JUMP 60
--  58: OUTPUT sF, 0x06      canary, must NOT execute
--  59: NOP
--  60: LOAD s3, 0x22
--  61: COMPARE s3, s3       zero=1
--  62: COMPARECY s3, s3     zero=1 (z_i=1)
--  63: JZ 66                taken, flush 64
--  64: OUTPUT sF, 0x06      canary, must NOT execute
--  65: NOP
--  66: OUTPUT s3, 0x0A      port 10 = 0x22
--  67: JUMP 67
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity cpu_instruction_tb is
end entity;

architecture sim of cpu_instruction_tb is

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
        variable saw_p2 : boolean := false;
        variable saw_p3 : boolean := false;
        variable saw_p4 : boolean := false;
        variable saw_p5 : boolean := false;
        variable saw_p7 : boolean := false;
        variable saw_p8 : boolean := false;
        variable saw_p9 : boolean := false;
        variable saw_p10: boolean := false;
        constant MAX_CYCLES : integer := 250;
    begin
        in_ports(5) <= x"AB";  -- INPUT s4 reads from in_ports(5)

        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';

        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- Canary: flushed instruction must never write port 6
            assert out_ports(6) /= x"EE"
                report "FAIL: canary 0xEE on port 6, flushed instruction executed"
                severity failure;

            -- NOP
            if out_ports(0) = x"42" and not saw_p0 then
                saw_p0 := true;
                report "NOP: port 0 = 0x42" severity note;
            end if;

            -- TEST reg + JC
            if out_ports(1) = x"FF" and not saw_p1 then
                saw_p1 := true;
                report "TEST reg + JC: port 1 = 0xFF" severity note;
            end if;

            -- TEST imm + JZ
            if out_ports(2) = x"F0" and not saw_p2 then
                saw_p2 := true;
                report "TEST imm + JZ: port 2 = 0xF0" severity note;
            end if;

            -- INPUT imm
            if out_ports(3) = x"AB" and not saw_p3 then
                saw_p3 := true;
                report "INPUT imm: port 3 = 0xAB" severity note;
            end if;

            -- OUTPUT reg (register-addressed port)
            if out_ports(4) = x"99" and not saw_p4 then
                saw_p4 := true;
                report "OUTPUT reg: port 4 = 0x99" severity note;
            end if;

            -- STORE + FETCH round-trip
            if out_ports(5) = x"55" and not saw_p5 then
                saw_p5 := true;
                report "STORE/FETCH: port 5 = 0x55" severity note;
            end if;

            -- TESTCY carry chain
            if out_ports(7) = x"03" and not saw_p7 then
                saw_p7 := true;
                report "TESTCY carry: port 7 = 0x03" severity note;
            end if;

            -- TESTCY zero chain
            if out_ports(8) = x"F0" and not saw_p8 then
                saw_p8 := true;
                report "TESTCY zero: port 8 = 0xF0" severity note;
            end if;

            -- COMPARECY z_i=0 (not taken)
            if out_ports(9) = x"01" and not saw_p9 then
                saw_p9 := true;
                report "COMPARECY z_i=0: port 9 = 0x01" severity note;
            end if;

            -- COMPARECY z_i=1 (taken)
            if out_ports(10) = x"22" and not saw_p10 then
                saw_p10 := true;
                report "COMPARECY z_i=1: port 10 = 0x22" severity note;
            end if;

            if saw_p0 and saw_p1 and saw_p2 and saw_p3 and saw_p4 and saw_p5
               and saw_p7 and saw_p8 and saw_p9 and saw_p10 then
                report "instruction tests passed" severity note;
                wait;
            end if;
        end loop;

        assert saw_p0 report "TIMEOUT: port 0 never 0x42 (NOP)" severity failure;
        assert saw_p1 report "TIMEOUT: port 1 never 0xFF (TEST reg)" severity failure;
        assert saw_p2 report "TIMEOUT: port 2 never 0xF0 (TEST imm)" severity failure;
        assert saw_p3 report "TIMEOUT: port 3 never 0xAB (INPUT imm)" severity failure;
        assert saw_p4 report "TIMEOUT: port 4 never 0x99 (OUTPUT reg)" severity failure;
        assert saw_p5 report "TIMEOUT: port 5 never 0x55 (STORE/FETCH)" severity failure;
        assert saw_p7 report "TIMEOUT: port 7 never 0x03 (TESTCY carry)" severity failure;
        assert saw_p8 report "TIMEOUT: port 8 never 0xF0 (TESTCY zero)" severity failure;
        assert saw_p9 report "TIMEOUT: port 9 never 0x01 (COMPARECY z_i=0)" severity failure;
        assert saw_p10 report "TIMEOUT: port 10 never 0x22 (COMPARECY z_i=1)" severity failure;
        wait;
    end process;

end architecture;

-- Custom ROM for this testbench (see program listing in header)
architecture InstructionTest of InstructionMemory is

    type rom_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    constant ROM : rom_type := (
        -- canary
        0  => "010101111111101110",  -- LOAD sF, 0xEE

        -- NOP test
        1  => "010101000001000010",  -- LOAD s0, 0x42
        2  => "000000000000000000",  -- NOP
        3  => "011001000000000000",  -- OUTPUT s0, 0x00

        -- TEST reg, odd parity -> carry=1
        4  => "010101000111111111",  -- LOAD s1, 0xFF
        5  => "010101001000000001",  -- LOAD s2, 0x01
        6  => "010010000100100000",  -- TEST s1, s2 (stall on s2)
        7  => "110011000000001011",  -- JC 11 (carry=1, taken)
        8  => "011001111100000110",  -- OUTPUT sF, 0x06 (canary, flushed)
        9  => "000000000000000000",  -- NOP
        10 => "000000000000000000",  -- NOP
        11 => "011001000100000001",  -- OUTPUT s1, 0x01

        -- TEST imm, result=0x00 -> zero=1
        12 => "010101001111110000",  -- LOAD s3, 0xF0
        13 => "010011001100001111",  -- TEST s3, 0x0F (stall on s3)
        14 => "110001000000010010",  -- JZ 18 (zero=1, taken)
        15 => "011001111100000110",  -- OUTPUT sF, 0x06 (canary, flushed)
        16 => "000000000000000000",  -- NOP
        17 => "000000000000000000",  -- NOP
        18 => "011001001100000010",  -- OUTPUT s3, 0x02

        -- INPUT imm
        19 => "010111010000000101",  -- INPUT s4, 0x05
        20 => "011001010000000011",  -- OUTPUT s4, 0x03 (stall on s4)

        -- OUTPUT reg (register-addressed port)
        21 => "010101010100000100",  -- LOAD s5, 0x04
        22 => "010101011010011001",  -- LOAD s6, 0x99
        23 => "011000011001010000",  -- OUTPUT s6, s5 (stall on s6)

        -- STORE + FETCH round-trip through scratchpad
        24 => "010101011101010101",  -- LOAD s7, 0x55
        25 => "011101011100010000",  -- STORE s7, 0x10 (stall on s7)
        26 => "000000000000000000",  -- NOP
        27 => "000000000000000000",  -- NOP
        28 => "010101100000010000",  -- LOAD s8, 0x10
        29 => "011010100110000000",  -- FETCH s9, s8 (stall on s8)
        30 => "011001100100000101",  -- OUTPUT s9, 0x05 (stall on s9)
        31 => "000000000000000000",  -- NOP

        -- TESTCY carry chain (c_i=1 => carry=1 even if parity even)
        32 => "010101101000000000",  -- LOAD sA, 0x00
        33 => "010101101100000001",  -- LOAD sB, 0x01
        34 => "000110101010110000",  -- SUB sA, sB (carry=1, zero=0)
        35 => "010101110000000011",  -- LOAD sC, 0x03
        36 => "010101110100000011",  -- LOAD sD, 0x03
        37 => "101100110011010000",  -- TESTCY sC, sD (parity even, c_i=1 -> carry=1)
        38 => "110011000000101010",  -- JC 42 (taken)
        39 => "011001111100000110",  -- OUTPUT sF, 0x06 (canary, flushed)
        40 => "000000000000000000",  -- NOP
        41 => "000000000000000000",  -- NOP
        42 => "011001110000000111",  -- OUTPUT sC, 0x07

        -- TESTCY zero chain (z_i=1 => zero stays 1 when result=0)
        43 => "010101111011110000",  -- LOAD sE, 0xF0
        44 => "010101000000001111",  -- LOAD s0, 0x0F
        45 => "010000111011100000",  -- COMPARE sE, sE (zero=1)
        46 => "101100111000000000",  -- TESTCY sE, s0 (result=0x00, z_i=1 -> zero=1)
        47 => "110001000000110010",  -- JZ 50 (taken)
        48 => "011001111100000110",  -- OUTPUT sF, 0x06 (canary, flushed)
        49 => "000000000000000000",  -- NOP
        50 => "011001111000001000",  -- OUTPUT sE, 0x08

        -- COMPARECY z_i=0 => zero must stay 0 even if equal
        51 => "010101000100000001",  -- LOAD s1, 0x01
        52 => "010101001000000001",  -- LOAD s2, 0x01
        53 => "010001000100000000",  -- COMPARE s1, 0x00 (carry=0, zero=0)
        54 => "011110000100100000",  -- COMPARECY s1, s2 (0x01-0x01-0=0x00, z_i=0 -> zero=0)
        55 => "110001000000111010",  -- JZ 58 (not taken)
        56 => "011001000100001001",  -- OUTPUT s1, 0x09
        57 => "110000000000111100",  -- JUMP 60
        58 => "011001111100000110",  -- OUTPUT sF, 0x06 (canary, must NOT execute)
        59 => "000000000000000000",  -- NOP

        -- COMPARECY z_i=1 => zero must stay 1 when equal
        60 => "010101001100100010",  -- LOAD s3, 0x22
        61 => "010000001100110000",  -- COMPARE s3, s3 (zero=1)
        62 => "011110001100110000",  -- COMPARECY s3, s3 (zero=1)
        63 => "110001000001000010",  -- JZ 66 (taken)
        64 => "011001111100000110",  -- OUTPUT sF, 0x06 (canary, flushed)
        65 => "000000000000000000",  -- NOP
        66 => "011001001100001010",  -- OUTPUT s3, 0x0A
        67 => "110000000001000011",  -- JUMP 67

        others => (others => '0')
    );

begin
    Instruction <= ROM(to_integer(unsigned(Address)));
end InstructionTest;

configuration cpu_instruction_tb_cfg of cpu_instruction_tb is
    for sim
        for uut: cpu
            use entity work.cpu(rtl);
            for rtl
                for rom: InstructionMemory
                    use entity work.InstructionMemory(InstructionTest);
                end for;
            end for;
        end for;
    end for;
end configuration;
