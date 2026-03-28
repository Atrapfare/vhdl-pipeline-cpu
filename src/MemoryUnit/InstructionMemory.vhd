----------------------------------------------------------------------------------
-- InstructionMemory -- ROM holding the boot program
--
-- Asynchronous read, no write port. Helper functions encode instructions
-- in a readable way. The default architecture contains a Fibonacci program.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity InstructionMemory is
    Generic (
        ADDR_WIDTH : integer := 12;
        DATA_WIDTH : integer := 18
    );
    Port (
        Address     : in  STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
        Instruction : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0)
    );
end InstructionMemory;

architecture Behavioral of InstructionMemory is

    -- Instruction builder helpers (keep the ROM table readable)

    pure function Op_Load_Im(RegAddr : integer; Val : integer) return std_logic_vector is
    begin
        return "010101" & std_logic_vector(to_unsigned(RegAddr, 4)) & std_logic_vector(to_unsigned(Val, 8));
    end function;

    pure function Op_Load_Reg(DestReg : integer; SrcReg : integer) return std_logic_vector is
    begin
        return "010100" & std_logic_vector(to_unsigned(DestReg, 4)) & std_logic_vector(to_unsigned(SrcReg, 4)) & "0000";
    end function;

    pure function Op_Add_Reg(DestReg : integer; SrcReg : integer) return std_logic_vector is
    begin
        return "000010" & std_logic_vector(to_unsigned(DestReg, 4)) & std_logic_vector(to_unsigned(SrcReg, 4)) & "0000";
    end function;

    pure function Op_Sub_Im(RegAddr : integer; Val : integer) return std_logic_vector is
    begin
        return "000111" & std_logic_vector(to_unsigned(RegAddr, 4)) & std_logic_vector(to_unsigned(Val, 8));
    end function;

    pure function Op_Comp_Im(RegAddr : integer; Val : integer) return std_logic_vector is
    begin
        return "010001" & std_logic_vector(to_unsigned(RegAddr, 4)) & std_logic_vector(to_unsigned(Val, 8));
    end function;

    pure function Op_Jump(OpCode : string; Addr : integer) return std_logic_vector is
    begin
        if OpCode = "ZERO" then return "110001" & std_logic_vector(to_unsigned(Addr, 12));
        elsif OpCode = "ALWAYS" then return "110000" & std_logic_vector(to_unsigned(Addr, 12));
        else return "000000000000000000";
        end if;
    end function;

    pure function Op_Out_Im(PortID : integer; SrcReg : integer) return std_logic_vector is
    begin
        return "011001" & std_logic_vector(to_unsigned(SrcReg, 4)) & std_logic_vector(to_unsigned(PortID, 8));
    end function;

    type rom_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Fibonacci: output the first 5 Fibonacci numbers (1,1,2,3,5) on port 0
    constant BOOT_ROM : rom_type := (
        0  => Op_Load_Im(0, 5),      -- r0 = loop counter
        1  => Op_Load_Im(10, 1),     -- rA = fib(n-1)
        2  => Op_Load_Im(11, 1),     -- rB = fib(n)
        3  => Op_Comp_Im(0, 0),      -- if counter == 0 then done
        4  => Op_Jump("ZERO", 11),
        5  => Op_Out_Im(0, 10),      -- OUTPUT rA to port 0
        6  => Op_Load_Reg(12, 10),   -- rC = rA (save old fib(n-1))
        7  => Op_Load_Reg(10, 11),   -- rA = rB
        8  => Op_Add_Reg(11, 12),    -- rB = rB + rC
        9  => Op_Sub_Im(0, 1),       -- counter--
        10 => Op_Jump("ALWAYS", 3),  -- loop
        11 => Op_Jump("ALWAYS", 11), -- halt
        4095 => "101010111100110011", -- end-of-ROM marker for synthesis boundary
        others => (others => '0')
    );

    attribute rom_style : string;
    attribute rom_style of BOOT_ROM : constant is "distributed";

begin

    Instruction <= BOOT_ROM(to_integer(unsigned(Address)));

end Behavioral;
