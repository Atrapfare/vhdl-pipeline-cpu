----------------------------------------------------------------------------------
-- Hazard Detector Testbench -- RAW hazard stall logic
--
-- Purely combinational DUT. Each test vector drives write_addr, write_enable,
-- decode-stage addresses, and read flags, then checks whether the stall
-- output is correct. Covers all interesting corner cases.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.all;
use std.env.all;

entity hazard_detector_tb is
end entity;

architecture sim of hazard_detector_tb is

    signal write_addr   : ro2_address := (others => '0');
    signal write_enable : std_logic := '0';
    signal addr_a       : ro2_address := (others => '0');
    signal addr_b       : ro2_address := (others => '0');
    signal reads_reg_a  : std_logic := '0';
    signal reads_reg_b  : std_logic := '0';
    signal stall        : std_logic;

begin

    dut: entity work.hazard_detector(rtl)
        port map (
            write_addr   => write_addr,
            write_enable => write_enable,
            addr_a       => addr_a,
            addr_b       => addr_b,
            reads_reg_a  => reads_reg_a,
            reads_reg_b  => reads_reg_b,
            stall        => stall
        );

    stim: process

        -- Apply one test vector and check stall output after 1 ns settle
        procedure expect_stall(
            constant wr_addr : ro2_address;
            constant wr_en   : std_logic;
            constant a_addr  : ro2_address;
            constant b_addr  : ro2_address;
            constant rd_a    : std_logic;
            constant rd_b    : std_logic;
            constant exp     : std_logic;
            constant msg     : string
        ) is
        begin
            write_addr   <= wr_addr;
            write_enable <= wr_en;
            addr_a       <= a_addr;
            addr_b       <= b_addr;
            reads_reg_a  <= rd_a;
            reads_reg_b  <= rd_b;
            wait for 1 ns;

            assert stall = exp
                report msg & ": expected stall=" & std_logic'image(exp)
                    & " got stall=" & std_logic'image(stall)
                severity error;
        end procedure;

    begin

        -- No hazard: write disabled even though addresses match
        expect_stall(x"1", '0', x"1", x"2", '1', '1', '0',
            "write disabled, matching addr_a");

        -- Hazard on sX (addr_a)
        expect_stall(x"1", '1', x"1", x"2", '1', '0', '1',
            "RAW hazard on addr_a");

        -- Hazard on sY (addr_b)
        expect_stall(x"2", '1', x"0", x"2", '0', '1', '1',
            "RAW hazard on addr_b");

        -- Hazard on both sX and sY
        expect_stall(x"3", '1', x"3", x"3", '1', '1', '1',
            "RAW hazard on both addr_a and addr_b");

        -- No hazard: different addresses
        expect_stall(x"5", '1', x"A", x"B", '1', '1', '0',
            "no hazard, addresses differ");

        -- No hazard: addr_a matches but instruction doesn't read sX (e.g. LOAD)
        expect_stall(x"1", '1', x"1", x"2", '0', '0', '0',
            "addr_a matches but not reading reg_a");

        -- No hazard: addr_b matches but instruction uses immediate
        expect_stall(x"2", '1', x"0", x"2", '0', '0', '0',
            "addr_b matches but not reading reg_b");

        -- Mixed: hazard on addr_a only, addr_b matches but reads_reg_b=0
        expect_stall(x"4", '1', x"4", x"4", '1', '0', '1',
            "hazard on addr_a, addr_b matches but not read");

        -- Mixed: hazard on addr_b only, addr_a matches but reads_reg_a=0
        expect_stall(x"4", '1', x"4", x"4", '0', '1', '1',
            "hazard on addr_b, addr_a matches but not read");

        -- Boundary: s0 (lowest register)
        expect_stall(x"0", '1', x"0", x"F", '1', '0', '1',
            "hazard on s0 (lowest register)");

        -- Boundary: sF (highest register)
        expect_stall(x"F", '1', x"0", x"F", '0', '1', '1',
            "hazard on sF (highest register)");

        -- Sanity: everything matches but write disabled -> no stall
        expect_stall(x"A", '0', x"A", x"A", '1', '1', '0',
            "all addresses match but write disabled");

        report "All hazard detector tests passed." severity note;
        stop;
        wait;
    end process;

end architecture;
