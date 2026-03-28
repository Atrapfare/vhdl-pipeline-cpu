----------------------------------------------------------------------------------
-- IO types package -- port_array type used by IO_Unit
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package io_types_pkg is
    -- 256 ports, each 8 bits wide
    type port_array is array (0 to 255) of std_logic_vector(7 downto 0);
end package io_types_pkg;

package body io_types_pkg is
end package body io_types_pkg;
