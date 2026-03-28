----------------------------------------------------------------------------------
-- DataMemory -- 256 x 8-bit scratchpad RAM
--
-- Synchronous write, asynchronous read.
-- Writes to address 0xFF produce a simulation debug report.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DataMemory is
    Generic (
        DATA_WIDTH : integer := 8;
        ADDR_WIDTH : integer := 8
    );
    Port (
        clk        : in  STD_LOGIC;
        Write_En   : in  STD_LOGIC;
        Address    : in  STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
        Data_In    : in  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
        Data_Out   : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0)
    );
end DataMemory;

architecture Behavioral of DataMemory is

    type ram_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal RAM : ram_type := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of RAM : signal is "distributed";

    constant ADDR_DEBUG_PORT : integer := 255;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if Write_En = '1' then
                RAM(to_integer(unsigned(Address))) <= Data_In;

                -- warn about undefined values during simulation
                if is_x(Data_In) then
                     report "DataMemory: undefined value (X/U) written to address "
                            & integer'image(to_integer(unsigned(Address)))
                     severity warning;
                end if;

                -- debug print on write to 0xFF
                if to_integer(unsigned(Address)) = ADDR_DEBUG_PORT then
                    report "Debug port write: " & integer'image(to_integer(unsigned(Data_In)));
                end if;
            end if;
        end if;
    end process;

    -- asynchronous read
    Data_Out <= RAM(to_integer(unsigned(Address)));

end Behavioral;
