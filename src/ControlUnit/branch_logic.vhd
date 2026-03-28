----------------------------------------------------------------------------------
-- Branch Logic -- decides whether a jump/branch is taken
--
-- Purely combinational: checks the requested condition against the
-- current carry and zero flags. Only active when jump_enable = '1'.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.alu_pkg.all;
use work.controlunit_pkg.all;

entity branch_logic is
    Port (
        carry_in     : in  std_logic;
        zero_in      : in  std_logic;
        jump_cond_in : in  jump_cond_t;
        jump_enable  : in  std_logic;      -- '1' when current instruction is a branch/jump
        branch_taken : out std_logic       -- '1' when the condition is met
    );
end branch_logic;

architecture rtl of branch_logic is

begin

    -- Evaluate the branch condition against current ALU flags
    process(carry_in, zero_in, jump_cond_in, jump_enable)
    begin
        if jump_enable = '1' then
            case jump_cond_in is
                when J_NONE =>
                    branch_taken <= '0';

                when J_UNCOND =>
                    branch_taken <= '1';

                when J_Z =>                     -- jump if zero flag set
                    if zero_in = '1' then
                        branch_taken <= '1';
                    else
                        branch_taken <= '0';
                    end if;

                when J_NZ =>                    -- jump if zero flag clear
                    if zero_in = '0' then
                        branch_taken <= '1';
                    else
                        branch_taken <= '0';
                    end if;

                when J_C =>                     -- jump if carry flag set
                    if carry_in = '1' then
                        branch_taken <= '1';
                    else
                        branch_taken <= '0';
                    end if;

                when J_NC =>                    -- jump if carry flag clear
                    if carry_in = '0' then
                        branch_taken <= '1';
                    else
                        branch_taken <= '0';
                    end if;

                when others =>
                    branch_taken <= '0';
            end case;
        else
            -- no jump instruction active, never branch
            branch_taken <= '0';
        end if;
    end process;

end architecture;
