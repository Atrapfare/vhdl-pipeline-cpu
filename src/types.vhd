----------------------------------------------------------------------------------
-- Common types -- shared across the entire CPU design
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package common is
    subtype ro2_word is std_logic_vector(7 downto 0);                -- 8-bit data word
    subtype ro2_address is std_logic_vector(3 downto 0);             -- 4-bit register address (16 regs)

    subtype ro2_instruction is std_logic_vector(17 downto 0);        -- 18-bit instruction word
    subtype ro2_instruction_address is std_logic_vector(11 downto 0); -- 12-bit program address space
end package;
