----------------------------------------------------------------------------------
-- Control Unit package -- shared types for branch/jump logic
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package controlunit_pkg is

    -- Possible branch/jump conditions evaluated by branch_logic
    type jump_cond_t is (
        J_NONE, J_Z, J_NZ, J_C, J_NC, J_UNCOND
    );

end controlunit_pkg;
