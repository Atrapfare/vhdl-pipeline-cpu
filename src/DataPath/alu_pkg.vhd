----------------------------------------------------------------------------------
-- ALU package -- operation type enumeration
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package alu_pkg is
    type alu_op_t is (
        ALU_ADD, ALU_ADDCY,             -- addition, addition with carry
        ALU_SUB, ALU_SUBCY,             -- subtraction, subtraction with carry
        ALU_AND, ALU_OR, ALU_XOR,       -- bitwise logic
        ALU_RL, ALU_RR,                 -- rotate left / right
        ALU_SL0, ALU_SL1,               -- shift left, fill with 0 or 1
        ALU_SLA, ALU_SLX,               -- shift left arithmetic / extend
        ALU_SR0, ALU_SR1,               -- shift right, fill with 0 or 1
        ALU_SRA, ALU_SRX,               -- shift right arithmetic / extend
        ALU_TEST,                       -- AND + odd-parity check (result in carry)
        ALU_COMPARECY,                  -- like SUBCY, flag-only (no writeback)
        ALU_TESTCY,                     -- like TEST but chains carry and zero via c_i/z_i
        ALU_PASS_B,                     -- passthrough B
        ALU_NOP
    );
end alu_pkg;
