----------------------------------------------------------------------------------
-- Register File -- 16 x 8-bit general purpose registers
--
-- Synchronous read and write on rising clock edge.
-- Read-first behavior: if you write and read the same address in the
-- same cycle, you get the old value; the new value appears next cycle.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.common.all;

entity regfile is
    Port(
        clock_in      : std_logic;
        reset_in      : in std_logic;
        do_write_in   : std_logic;              -- write enable
        addr_write_in : in ro2_address;         -- which register to write
        data_in       : in ro2_word;            -- value to write
        addrA_in      : in ro2_address;         -- read port A address
        addrB_in      : in ro2_address;         -- read port B address
        A_out         : out ro2_word;           -- read port A data
        B_out         : out ro2_word            -- read port B data
    );
end regfile;

architecture rtl of regfile is
    type reg_array_t is array (15 downto 0) of ro2_word;
    signal regs : reg_array_t := (others => (others => '0'));

    signal A_s: ro2_word := (others => '0');
    signal B_s: ro2_word := (others => '0');

begin
    process(clock_in)
    begin
        if rising_edge(clock_in) then

            -- write
            if reset_in = '1' then
                regs <= (others => (others => '0'));
            elsif do_write_in = '1' then
                regs(to_integer(unsigned(addr_write_in))) <= data_in;
            end if;

            -- read (registered output, one cycle latency)
            if reset_in = '1' then
                A_s <= (others => '0');
                B_s <= (others => '0');
            else
                A_s <= regs(to_integer(unsigned(addrA_in)));
                B_s <= regs(to_integer(unsigned(addrB_in)));
            end if;

        end if;
    end process;

    A_out <= A_s;
    B_out <= B_s;

end rtl;
