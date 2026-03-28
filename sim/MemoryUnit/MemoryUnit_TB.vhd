library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------------
-- DataMemory Testbench -- scratchpad RAM read/write verification
--
-- Tests: initial zero state, basic write/read, write protection (Write_En=0),
-- debug port persistence (addr 0xFF), and a multi-address sweep.
--
----------------------------------------------------------------------------------

entity MemoryUnit_TB is
end MemoryUnit_TB;

architecture Behavioral of MemoryUnit_TB is

    component DataMemory
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
    end component;

    signal clk        : std_logic := '0';
    signal Write_En   : std_logic := '0';
    signal Address    : std_logic_vector(7 downto 0) := (others => '0');
    signal Data_In    : std_logic_vector(7 downto 0) := (others => '0');
    signal Data_Out   : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 20 ns;

begin

    uut: DataMemory
        Generic Map (
            DATA_WIDTH => 8,
            ADDR_WIDTH => 8
        )
        Port map (
            clk        => clk,
            Write_En   => Write_En,
            Address    => Address,
            Data_In    => Data_In,
            Data_Out   => Data_Out
        );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc: process

        -- Write one byte: sync to falling edge for proper setup time
        procedure Write_Mem(addr_val : integer; data_val : integer) is
        begin
            wait until falling_edge(clk);
            Write_En <= '1';
            Address  <= std_logic_vector(to_unsigned(addr_val, 8));
            Data_In  <= std_logic_vector(to_unsigned(data_val, 8));
            wait for CLK_PERIOD;
            Write_En <= '0';
        end procedure;

        -- Read one byte (async) and compare against expected value
        procedure Check_Mem(addr_val : integer; expected_val : integer; test_name : string) is
        begin
            wait until falling_edge(clk);
            Address <= std_logic_vector(to_unsigned(addr_val, 8));
            wait for CLK_PERIOD;

            assert to_integer(unsigned(Data_Out)) = expected_val
                report "[FAIL] " & test_name & ": Addr " & integer'image(addr_val) &
                       " Expected " & integer'image(expected_val) &
                       " Got " & integer'image(to_integer(unsigned(Data_Out)))
                severity error;
        end procedure;

    begin
        -- RAM should power up as all zeros
        Check_Mem(0, 0, "Init Read Addr 0");
        Check_Mem(255, 0, "Init Read Addr 255");

        -- Basic write/read
        Write_Mem(1, 170); -- 0xAA
        Check_Mem(1, 170, "Read 0xAA from Addr 1");

        Write_Mem(2, 85);  -- 0x55
        Check_Mem(2, 85, "Read 0x55 from Addr 2");

        -- Write protection: Write_En=0 must not modify content
        wait until falling_edge(clk);
        Write_En <= '0';
        Address  <= std_logic_vector(to_unsigned(1, 8));
        Data_In  <= std_logic_vector(to_unsigned(255, 8));
        wait for CLK_PERIOD;

        Check_Mem(1, 170, "Write Protect Check");

        -- Debug port (0xFF): value persists normally
        Write_Mem(255, 42);
        Check_Mem(255, 42, "Debug Port Persistence");

        -- Multi-address sweep
        for i in 10 to 20 loop
            Write_Mem(i, i + 10);
        end loop;

        for i in 10 to 20 loop
            Check_Mem(i, i + 10, "Sweep Check");
        end loop;

        report "MemoryUnit_TB: all tests passed";
        wait;
    end process;

end Behavioral;
