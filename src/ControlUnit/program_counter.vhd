----------------------------------------------------------------------------------
-- Program Counter -- tracks the address of the next instruction
--
-- Synchronous counter with enable gating. On each rising clock edge:
--   reset=1        => PC goes to 0
--   enable=0       => PC holds (used during pipeline stalls)
--   branch_jump=1  => PC loads the absolute jump_address
--   otherwise      => PC increments by 1
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.alu_pkg.all;
use work.controlunit_pkg.all;

entity program_counter is
    Port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        branch_jump  : in  std_logic;                      -- '1' to load jump target instead of incrementing
        enable       : in  std_logic;                      -- '0' freezes the PC (stall)
        jump_address : in  std_logic_vector(11 downto 0);  -- 12-bit absolute target
        pc_out       : out std_logic_vector(11 downto 0)
    );
end program_counter;

architecture rtl of program_counter is
    signal pc_reg : std_logic_vector(11 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc_reg <= (others => '0');
            elsif enable = '1' then
                if branch_jump = '1' then
                    pc_reg <= jump_address;         -- absolute jump
                else
                    pc_reg <= std_logic_vector(unsigned(pc_reg) + 1);
                end if;
            end if;
            -- enable='0': PC stays unchanged (stall)
        end if;
    end process;

    pc_out <= pc_reg;
end rtl;
