----------------------------------------------------------------------------------
-- CPU False Stall / Far Jump Testbench
--
-- Verifies that a far JUMP (to address 256) lands correctly and that
-- a real RAW hazard (ADD s1,s3 after LOAD s3) stalls and resolves
-- properly. Canary value 0xBB catches the flushed delay-slot instruction.
--
--   0: LOAD sE, 0xBB
--   1: LOAD s1, 0x42
--   2: JUMP 256
--   3: OUTPUT sE, 0x00      must NOT execute (flushed)
-- 256: OUTPUT s1, 0x00      port 0 = 0x42
-- 257: LOAD s3, 0x10
-- 258: ADD s1, s3            stall on s3, s1 = 0x42+0x10 = 0x52
-- 259: OUTPUT s1, 0x00      port 0 = 0x52
-- 260: JUMP 260
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity cpu_stall_tb is
end entity;

architecture sim of cpu_stall_tb is

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
        variable saw_42     : boolean := false;
        variable saw_52     : boolean := false;
        constant MAX_CYCLES : integer := 80;
    begin
        reset <= '1';
        wait for CLK_PERIOD * 3;
        reset <= '0';

        while cycles < MAX_CYCLES loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- Canary: flushed OUTPUT sE must never appear
            assert out_ports(0) /= x"BB"
                report "FAIL: canary value 0xBB observed on port 0: flushed instruction executed"
                severity failure;

            -- Far jump landed (s1 = 0x42)
            if out_ports(0) = x"42" and not saw_42 then
                saw_42 := true;
                report "Jump landed: port 0 = 0x42" severity note;
            end if;

            -- Stall resolved (s1 = 0x42 + 0x10 = 0x52)
            if out_ports(0) = x"52" and not saw_52 then
                saw_52 := true;
                report "Real stall resolved: port 0 = 0x52" severity note;
            end if;

            if saw_42 and saw_52 then
                report "All stall hazard tests passed" severity note;
                wait;
            end if;
        end loop;

        if not saw_42 then
            report "TIMEOUT: never observed 0x42 on port 0"
                severity failure;
        end if;
        if not saw_52 then
            report "TIMEOUT: never observed 0x52 on port 0"
                severity failure;
        end if;
        wait;
    end process;

end architecture;

-- Custom ROM with a far jump to address 256
architecture StallTest of InstructionMemory is

    type rom_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    constant ROM : rom_type := (
        0 => "010101111010111011",    -- LOAD sE, 0xBB
        1 => "010101000101000010",    -- LOAD s1, 0x42
        2 => "110000000100000000",    -- JUMP 256
        3 => "011001111000000000",    -- OUTPUT sE, 0x00 (must never execute)

        256 => "011001000100000000",  -- OUTPUT s1, 0x00
        257 => "010101001100010000",  -- LOAD s3, 0x10
        258 => "000010000100110000",  -- ADD s1, s3
        259 => "011001000100000000",  -- OUTPUT s1, 0x00
        260 => "110000000100000100",  -- JUMP 260

        others => (others => '0')
    );

begin
    Instruction <= ROM(to_integer(unsigned(Address)));
end StallTest;

configuration cpu_stall_tb_cfg of cpu_stall_tb is
    for sim
        for uut: cpu
            use entity work.cpu(rtl);
            for rtl
                for rom: InstructionMemory
                    use entity work.InstructionMemory(StallTest);
                end for;
            end for;
        end for;
    end for;
end configuration;
