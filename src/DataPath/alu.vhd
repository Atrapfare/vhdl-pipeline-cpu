----------------------------------------------------------------------------------
-- ALU -- 8-bit arithmetic / logic unit
--
-- Purely combinational. Computes result, carry, and zero flag for
-- every supported operation in a single process.
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.alu_pkg.all;

entity alu is
    Port(
        a_i    : in  std_logic_vector(7 downto 0);  -- operand A (sX)
        b_i    : in  std_logic_vector(7 downto 0);  -- operand B (sY or immediate)
        c_i    : in  std_logic;                      -- carry in from flag register
        z_i    : in  std_logic;                      -- zero in from flag register (for *CY ops)
        op     : in  alu_op_t;
        result : out std_logic_vector(7 downto 0);
        c_o    : out std_logic;                      -- carry out
        z_o    : out std_logic                       -- zero flag
         );
end alu;

architecture rtl of alu is

begin
    process(a_i, b_i, c_i, z_i, op)
        variable r            : std_logic_vector(7 downto 0) := (others => '0');
        variable c            : std_logic := '0';
        variable z            : std_logic := '0';
        variable tmp          : unsigned(8 downto 0) := (others => '0'); -- 9 bits to capture carry/borrow
        variable propagate_z  : boolean := false;  -- skip default z computation for *CY ops
    begin
        r := (others => '0');
        c := '0';
        z := '0';
        propagate_z := false;

        case op is

            -- Addition
            when ALU_ADD =>
                tmp := ('0' & unsigned(a_i)) + ('0' & unsigned(b_i));
                r  := std_logic_vector(tmp(7 downto 0));
                c  := tmp(8);
            when ALU_ADDCY =>
                if c_i = '1' then
                    tmp := ('0' & unsigned(a_i)) + ('0' & unsigned(b_i)) + 1;
                else
                    tmp := ('0' & unsigned(a_i)) + ('0' & unsigned(b_i));
                end if;
                r  := std_logic_vector(tmp(7 downto 0));
                c  := tmp(8);
                -- z = (result == 0) AND z_i
                if r = x"00" and z_i = '1' then
                    z := '1';
                end if;
                propagate_z := true;

            -- Subtraction (carry = borrow)
            when ALU_SUB =>
                tmp := ('0' & unsigned(a_i)) - ('0' & unsigned(b_i));
                r  := std_logic_vector(tmp(7 downto 0));
                c  := tmp(8);
            when ALU_SUBCY =>
                if c_i = '1' then
                    tmp := ('0' & unsigned(a_i)) - ('0' & unsigned(b_i)) - 1;
                else
                    tmp := ('0' & unsigned(a_i)) - ('0' & unsigned(b_i));
                end if;
                r  := std_logic_vector(tmp(7 downto 0));
                c  := tmp(8);
                -- z = (result == 0) AND z_i
                if r = x"00" and z_i = '1' then
                    z := '1';
                end if;
                propagate_z := true;

            -- Bitwise logic
            when ALU_AND =>
                r := a_i and b_i;
            when ALU_OR  =>
                r := a_i or b_i;
            when ALU_XOR =>
                r := a_i xor b_i;

            -- Rotates: bit that falls off goes into carry and wraps around
            when ALU_RL =>
                c := a_i(7);
                r := a_i(6 downto 0) & a_i(7);
            when ALU_RR =>
                c := a_i(0);
                r := a_i(0) & a_i(7 downto 1);

            -- Shifts: bit that falls off goes into carry, fill bit varies
            when ALU_SL0 =>
                c := a_i(7);
                r := a_i(6 downto 0) & '0';
            when ALU_SL1 =>
                c := a_i(7);
                r := a_i(6 downto 0) & '1';
            when ALU_SLA =>
                c := a_i(7);
                r := a_i(6 downto 0) & c_i;        -- fill with old carry
            when ALU_SLX =>
                c := a_i(7);
                r := a_i(6 downto 0) & a_i(0);     -- replicate LSB
            when ALU_SR0 =>
                c := a_i(0);
                r := '0' & a_i(7 downto 1);
            when ALU_SR1 =>
                c := a_i(0);
                r := '1' & a_i(7 downto 1);
            when ALU_SRA =>
                c := a_i(0);
                r := c_i & a_i(7 downto 1);        -- fill with old carry
            when ALU_SRX =>
                c := a_i(0);
                r := a_i(7) & a_i(7 downto 1);     -- sign-extend (replicate MSB)

            -- TEST: AND then check parity of result
            when ALU_TEST =>
                r := a_i and b_i;
                c := r(7) xor r(6) xor r(5) xor r(4)
                     xor r(3) xor r(2) xor r(1) xor r(0);  -- carry = odd parity

            -- COMPARECY: like SUBCY but no writeback
            when ALU_COMPARECY =>
                if c_i = '1' then
                    tmp := ('0' & unsigned(a_i)) - ('0' & unsigned(b_i)) - 1;
                else
                    tmp := ('0' & unsigned(a_i)) - ('0' & unsigned(b_i));
                end if;
                r  := std_logic_vector(tmp(7 downto 0));
                c  := tmp(8);
                if r = x"00" and z_i = '1' then
                    z := '1';
                end if;
                propagate_z := true;

            -- TESTCY: like TEST but parity OR'd with c_i, zero uses z_i
            when ALU_TESTCY =>
                r := a_i and b_i;
                c := (r(7) xor r(6) xor r(5) xor r(4)
                      xor r(3) xor r(2) xor r(1) xor r(0)) or c_i;
                if r = x"00" and z_i = '1' then
                    z := '1';
                end if;
                propagate_z := true;

            when ALU_NOP =>
                r := (others => '0');

            -- Passthrough
            when ALU_PASS_B =>
                r := b_i;
        end case;

        result <= r;
        c_o    <= c;

        -- default zero flag (skipped for *CY ops which handle it above)
        if not propagate_z then
            if r = x"00" then
                z := '1';
            end if;
        end if;
        z_o <= z;


    end process;
end architecture;
