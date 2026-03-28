----------------------------------------------------------------------------------
-- Datapath -- connects register file and ALU, handles pipeline staging
-- and write-back.
--
-- Two-stage pipeline: decode -> execute. Signals from the control unit
-- are captured in pipeline registers on the rising clock edge and drive
-- the ALU one cycle later. Reset, stall, and flush all insert a bubble
-- by clearing the pipeline registers.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.all;
use work.alu_pkg.all;

entity datapath is
    Port (
        clock_in         : in  std_logic;
        reset_in         : in  std_logic;
        stall_in         : in  std_logic;
        flush_in         : in  std_logic;
        op_in            : in  alu_op_t;
        addrA_in         : in  ro2_address;      -- sX (destination / first source)
        addrB_in         : in  ro2_address;      -- sY (second source)
        const_in         : in  ro2_word;         -- 8-bit immediate from decoder
        use_const_in     : in  std_logic;        -- '1' to use immediate instead of reg B
        data_in          : in  ro2_word;         -- external data (IO read / memory fetch)
        use_data_in      : in  std_logic;        -- '1' to write data_in instead of ALU result
        do_write_in      : in  std_logic;        -- register write-back enable
        flag_write_in    : in  std_logic;        -- '1' when flags should be updated
        address_out      : out ro2_word;         -- ALU result (used as memory/IO address)
        data_out         : out ro2_word;         -- register A value (data to write to mem/IO)
        carry_flag_out   : out std_logic;
        zero_flag_out    : out std_logic;
        write_addr_out   : out ro2_address;      -- forwarded to hazard detector
        write_enable_out : out std_logic         -- forwarded to hazard detector
    );
end entity;

architecture rtl of datapath is

    -- Pipeline registers (decode -> execute)
    signal const_delay1_s       : ro2_word := (others => '0');
    signal use_const_delay1_s   : std_logic := '0';
    signal use_data_delay1_s    : std_logic := '0';
    signal flag_write_delay1_s  : std_logic := '0';

    -- Register file outputs
    signal A     : ro2_word := (others => '0');
    signal B_reg : ro2_word := (others => '0');

    -- ALU input / output
    signal op_alu_s   : alu_op_t := ALU_NOP;
    signal B_alu      : ro2_word := (others => '0');
    signal alu_result : ro2_word := (others => '0');

    signal carry_s : std_logic := '0';
    signal zero_s  : std_logic := '0';

    -- Registered flags (only updated when flag_write_delay1_s = '1')
    signal carry_reg : std_logic := '0';
    signal zero_reg  : std_logic := '0';

    -- Write-back pipeline
    signal addr_write_delay1_s : ro2_address := (others => '0');
    signal do_write_delay1_s   : std_logic := '0';
    signal writeback_s         : ro2_word := (others => '0');

begin

    regfile: entity work.regfile port map (
        clock_in      => clock_in,
        reset_in      => reset_in,
        do_write_in   => do_write_delay1_s,
        addr_write_in => addr_write_delay1_s,
        data_in       => writeback_s,
        addrA_in      => addrA_in,
        addrB_in      => addrB_in,
        A_out         => A,
        B_out         => B_reg
    );

    alu: entity work.alu port map (
        op     => op_alu_s,
        a_i    => A,
        b_i    => B_alu,
        c_i    => carry_reg,
        z_i    => zero_reg,
        result => alu_result,
        c_o    => carry_s,
        z_o    => zero_s
    );

    -- Capture decode-stage signals into execute-stage pipeline registers.
    -- Reset / stall / flush insert a NOP bubble (all enables cleared).
    process (clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' or stall_in = '1' or flush_in = '1' then
                op_alu_s            <= ALU_NOP;
                const_delay1_s      <= (others => '0');
                use_const_delay1_s  <= '0';
                flag_write_delay1_s <= '0';
                use_data_delay1_s   <= '0';
                addr_write_delay1_s <= (others => '0');
                do_write_delay1_s   <= '0';
            else
                op_alu_s            <= op_in;
                const_delay1_s      <= const_in;
                use_const_delay1_s  <= use_const_in;
                flag_write_delay1_s <= flag_write_in;
                use_data_delay1_s   <= use_data_in;
                addr_write_delay1_s <= addrA_in;
                do_write_delay1_s   <= do_write_in;
            end if;
        end if;
    end process;

    -- Flag registers: only update when the executing instruction actually affects flags
    process (clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' then
                carry_reg <= '0';
                zero_reg  <= '0';
            elsif flag_write_delay1_s = '1' then
                carry_reg <= carry_s;
                zero_reg  <= zero_s;
            end if;
        end if;
    end process;

    -- ALU B input mux: immediate or register
    B_alu <= const_delay1_s when use_const_delay1_s = '1' else B_reg;

    -- Write-back mux: external data (IO/memory) takes priority over ALU result
    -- data_in is already aligned to the execute stage, so no extra pipeline needed
    writeback_s <= data_in when use_data_delay1_s = '1' else alu_result;

    -- Flag outputs: show new flags immediately when flag-affecting, else hold registered
    carry_flag_out <= carry_s when flag_write_delay1_s = '1' else carry_reg;
    zero_flag_out  <= zero_s when flag_write_delay1_s = '1' else zero_reg;

    address_out <= B_alu;
    data_out    <= A;

    -- Expose delayed write signals so the hazard detector can compare them
    write_addr_out   <= addr_write_delay1_s;
    write_enable_out <= do_write_delay1_s;

end architecture;
