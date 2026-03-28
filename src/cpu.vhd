----------------------------------------------------------------------------------
-- CPU (top-level) -- integrates control unit, datapath, hazard detector,
-- instruction/data memory, and IO unit into a complete processor.
--
-- Pipeline: fetch (ROM) -> decode (control unit) -> execute (ALU/regfile)
-- IO and memory control signals are delayed one cycle so they align with
-- the execute-stage data coming out of the datapath.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.alu_pkg.all;
use work.common.all;
use work.io_types_pkg.all;

entity cpu is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        in_ports  : in  port_array;
        out_ports : out port_array;

        -- Bus interface
        port_id      : out std_logic_vector(7 downto 0);
        out_port     : out std_logic_vector(7 downto 0);
        write_strobe : out std_logic;
        read_strobe  : out std_logic
    );
end cpu;

architecture rtl of cpu is

    component InstructionMemory is
        Generic (
            ADDR_WIDTH : integer := 12;
            DATA_WIDTH : integer := 18
        );
        Port (
            Address     : in  STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
            Instruction : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0)
        );
    end component;

    -- instruction ROM
    signal instruction_s      : std_logic_vector(17 downto 0);
    signal program_counter_s  : std_logic_vector(11 downto 0);

    -- scratchpad RAM
    signal mem_read_s         : std_logic;
    signal mem_write_s        : std_logic;
    signal mem_read_delayed   : std_logic := '0';
    signal mem_write_delayed  : std_logic := '0';
    signal address_out_s      : ro2_word;
    signal mem_data_out_s     : ro2_word;

    -- datapath
    signal op_s               : alu_op_t := ALU_NOP;
    signal addrA_s            : ro2_address := (others => '0');
    signal addrB_s            : ro2_address := (others => '0');
    signal const_s            : ro2_word := (others => '0');
    signal use_const_s        : std_logic := '0';
    signal data_in_s          : ro2_word := (others => '0');
    signal use_data_in_s      : std_logic := '0';
    signal do_write_register_s: std_logic := '0';
    signal data_out_s         : ro2_word := (others => '0');

    -- flags
    signal carry_flag_s       : std_logic := '0';
    signal zero_flag_s        : std_logic := '0';
    signal flag_write_s       : std_logic := '0';

    -- hazard detection
    signal stall_s            : std_logic := '0';
    signal write_addr_out_s   : ro2_address := (others => '0');
    signal write_enable_out_s : std_logic := '0';
    signal reads_reg_a_s      : std_logic := '0';
    signal reads_reg_b_s      : std_logic := '0';

    -- pipeline flush on taken branch
    signal flush_s            : std_logic := '0';

    -- IO control (raw from decoder, active during decode)
    signal io_rd_s            : std_logic := '0';
    signal io_wr_s            : std_logic := '0';

    -- IO control (delayed one cycle to match execute-stage data)
    signal io_rd_delayed      : std_logic := '0';
    signal io_wr_delayed      : std_logic := '0';

    -- IO data
    signal io_data_out_s      : std_logic_vector(7 downto 0);
    signal cpu_data_in_s      : std_logic_vector(7 downto 0);

begin

    -- Instruction ROM
    rom: InstructionMemory generic map (
        DATA_WIDTH => 18,
        ADDR_WIDTH => 12
    ) port map (
        Instruction => instruction_s,
        Address     => program_counter_s
    );

    -- Control Unit
    control_unit: entity work.control_unit port map (
        clk         => clk,
        reset       => reset,
        stall_in    => stall_s,
        instruction => instruction_s,
        carry_in    => carry_flag_s,
        zero_in     => zero_flag_s,
        pc_out      => program_counter_s,
        flush_out   => flush_s,
        alu_op      => op_s,
        reg_write   => do_write_register_s,
        mem_read    => mem_read_s,
        mem_write   => mem_write_s,
        alu_src     => use_const_s,
        imm_out     => const_s,
        reg_dst     => addrA_s,
        reg_src_b   => addrB_s,
        flag_write  => flag_write_s,
        io_rd       => io_rd_s,
        io_wr       => io_wr_s,
        reads_reg_a => reads_reg_a_s,
        reads_reg_b => reads_reg_b_s
    );

    -- Datapath (register file + ALU + pipeline registers)
    data_path: entity work.datapath port map (
        clock_in         => clk,
        reset_in         => reset,
        stall_in         => stall_s,
        flush_in         => flush_s,
        op_in            => op_s,
        addrA_in         => addrA_s,
        addrB_in         => addrB_s,
        const_in         => const_s,
        use_const_in     => use_const_s,
        data_in          => data_in_s,
        use_data_in      => use_data_in_s,
        do_write_in      => do_write_register_s,
        flag_write_in    => flag_write_s,
        address_out      => address_out_s,
        data_out         => data_out_s,
        carry_flag_out   => carry_flag_s,
        zero_flag_out    => zero_flag_s,
        write_addr_out   => write_addr_out_s,
        write_enable_out => write_enable_out_s
    );

    -- Hazard Detector (stalls pipeline on RAW dependencies)
    hazard_det: entity work.hazard_detector port map (
        write_addr   => write_addr_out_s,
        write_enable => write_enable_out_s,
        addr_a       => addrA_s,
        addr_b       => addrB_s,
        reads_reg_a  => reads_reg_a_s,
        reads_reg_b  => reads_reg_b_s,
        stall        => stall_s
    );

    -- Pipeline IO/memory control by one cycle so they fire during execute, not during decode (otherwise io_wr/mem_write act on stale data)
    io_mem_pipeline: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or stall_s = '1' or flush_s = '1' then
                io_rd_delayed     <= '0';
                io_wr_delayed     <= '0';
                mem_read_delayed  <= '0';
                mem_write_delayed <= '0';
            else
                io_rd_delayed     <= io_rd_s;
                io_wr_delayed     <= io_wr_s;
                mem_read_delayed  <= mem_read_s;
                mem_write_delayed <= mem_write_s;
            end if;
        end if;
    end process;

    -- IO Unit
    io_unit_inst : entity work.IO_Unit port map (
        clk         => clk,
        rst         => reset,
        io_rd       => io_rd_delayed,
        io_wr       => io_wr_delayed,
        port_pp     => address_out_s,   -- port address comes from ALU result
        cpu_data_in => cpu_data_in_s,
        io_data_out => io_data_out_s,
        in_ports    => in_ports,
        out_ports   => out_ports
    );

    -- Scratchpad RAM
    ram: entity work.DataMemory generic map (
        DATA_WIDTH => 8,
        ADDR_WIDTH => 8
    ) port map (
        clk      => clk,
        Write_En => mem_write_delayed,
        Address  => address_out_s,
        Data_In  => data_out_s,
        Data_Out => mem_data_out_s
    );

    -- CPU -> IO (OUTPUT instruction): sX value goes to IO unit
    cpu_data_in_s <= data_out_s(7 downto 0);

    -- IO/Memory -> CPU (INPUT or FETCH): pick the right source
    data_in_s <= io_data_out_s  when io_rd_delayed  = '1' else
                 mem_data_out_s when mem_read_delayed = '1' else
                 (others => '0');

    -- use_data_in is captured in the datapath pipeline (decode -> execute)
    use_data_in_s <= io_rd_s or mem_read_s;

    -- Bus interface
    port_id      <= address_out_s when io_wr_delayed = '1' else (others => '0');
    out_port     <= data_out_s when io_wr_delayed = '1' else (others => '0');
    write_strobe <= io_wr_delayed;
    read_strobe  <= io_rd_delayed;

end architecture;
