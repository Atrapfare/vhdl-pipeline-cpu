----------------------------------------------------------------------------------
-- IO Unit -- bridges the CPU to 256 external input/output ports
--
-- Write: synchronous, stores cpu_data_in into the selected output port
-- Read:  combinational, returns the selected input port (zeros when idle)
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.io_types_pkg.all;

entity IO_Unit is
    generic (
        DATA_WIDTH : integer := 8;
        PORT_WIDTH : integer := 8
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- CPU interface
        io_rd        : in  std_logic;                                  -- INPUT instruction
        io_wr        : in  std_logic;                                  -- OUTPUT instruction
        port_pp      : in  std_logic_vector(PORT_WIDTH-1 downto 0);   -- port address

        cpu_data_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);   -- data from CPU (OUTPUT)
        io_data_out  : out std_logic_vector(DATA_WIDTH-1 downto 0);   -- data to CPU (INPUT)

        -- External world
        in_ports     : in  port_array;
        out_ports    : out port_array
    );
end IO_Unit;

architecture rtl of IO_Unit is

    signal out_ports_reg : port_array := (others => (others => '0'));
begin

    -- Synchronous write to output port register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_ports_reg <= (others => (others => '0'));
            elsif io_wr = '1' then
                out_ports_reg(to_integer(unsigned(port_pp)))
                    <= cpu_data_in;
            end if;
        end if;
    end process;

    -- Combinational read: selected input port goes to CPU, zeros when not reading
    io_data_out <= in_ports(to_integer(unsigned(port_pp))) when io_rd = '1' else (others => '0');

    out_ports <= out_ports_reg;

end rtl;
