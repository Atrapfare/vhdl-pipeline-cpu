----------------------------------------------------------------------------------
-- Hazard Detector -- stalls the pipeline on RAW (Read After Write) hazards
--
-- Purely combinational. Compares the execute-stage destination register
-- against the decode-stage source registers. Stall fires when:
--   1) the execute stage is actually writing (write_enable = '1'), AND
--   2) the decode stage reads a register that matches the write destination
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.all;

entity hazard_detector is
    Port (
        write_addr   : in  ro2_address;  -- execute-stage destination
        write_enable : in  std_logic;    -- execute-stage write enable
        addr_a       : in  ro2_address;  -- decode-stage source A (sX)
        addr_b       : in  ro2_address;  -- decode-stage source B (sY)
        reads_reg_a  : in  std_logic;    -- '1' when decode actually reads sX
        reads_reg_b  : in  std_logic;    -- '1' when decode actually reads sY
        stall        : out std_logic
    );
end hazard_detector;

architecture rtl of hazard_detector is
begin
    -- stall when execute is writing a register that decode needs to read
    stall <= '1' when write_enable = '1'
        and ((write_addr = addr_a and reads_reg_a = '1') or (write_addr = addr_b and reads_reg_b = '1')) else '0';
end rtl;
