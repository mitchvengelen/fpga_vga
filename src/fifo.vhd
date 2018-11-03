library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity fifo is
    generic(
        -- input / ouput data width of fifo
        data_width : integer := 8;

        -- depth of fifo
        -- 2^n = fifo data depth
        -- Example: 2^8 = 256 values can be stored in fifo
        data_depth : integer := 8
    );

    port(
        -- push side of fifo
        push        : in  std_logic;
        full        : out std_logic;
        clock_push  : in  std_logic;
        data_in     : in  std_logic_vector(data_width - 1 downto 0);

        -- pop side of fifo
        pop         : in  std_logic;
        empty       : out std_logic;
        clock_pop   : in  std_logic;
        data_out    : out std_logic_vector(data_width - 1 downto 0);

        -- asynchronous reset
        reset       : in  std_logic
    );
end fifo;

architecture rtl of fifo is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector(data_width - 1 downto 0);
	type memory_t is array(2 ** data_depth - 1  downto 0) of word_t;
	
	-- Declare the RAM
	shared variable ram : memory_t;

    -- all signals for the push side of fifo
    signal s_push_pointer           : std_logic_vector(data_depth - 1 downto 0);
    signal s_push_state             : std_logic;
    signal s_push_pop_pointer       : std_logic_vector(data_depth - 1 downto 0);
    signal s_push_synchronizer_s1   : std_logic_vector(data_depth - 1 downto 0);
    signal s_push_synchronizer_s2   : std_logic_vector(data_depth - 1 downto 0);
    signal s_push_gray_pointer      : std_logic_vector(data_depth - 1 downto 0);
    signal s_push_gray_pointer_delay: std_logic_vector(data_depth - 1 downto 0);

    -- all signals for the pop side of fifo
    signal s_pop_pointer           : std_logic_vector(data_depth - 1 downto 0);
    signal s_pop_state             : std_logic;
    signal s_pop_push_pointer      : std_logic_vector(data_depth - 1 downto 0);
    signal s_pop_synchronizer_s1   : std_logic_vector(data_depth - 1 downto 0);
    signal s_pop_synchronizer_s2   : std_logic_vector(data_depth - 1 downto 0);
    signal s_pop_gray_pointer      : std_logic_vector(data_depth - 1 downto 0);
    signal s_pop_gray_pointer_delay: std_logic_vector(data_depth - 1 downto 0);

begin

    -- pop side of fifo
    empty <= not s_pop_state;

    --binary to gray code -> for use in push controller
    s_pop_gray_pointer <= s_pop_pointer(data_depth - 1 downto 0) xor ('0' & s_pop_pointer(data_depth - 1 downto 1));

    --gray code to binary -> for use in pop controller
    process(s_pop_push_pointer, s_pop_synchronizer_s2)
    begin
        s_pop_push_pointer(data_depth - 1) <= s_pop_synchronizer_s2(data_depth - 1);

        for I in data_depth - 2 downto 0 loop
            s_pop_push_pointer(I) <= s_pop_synchronizer_s2(I) xor s_pop_push_pointer(I + 1);
        end loop;
    end process;

    process(clock_pop, reset)
    begin
        if reset = '1' then
            s_pop_pointer <= (others => '0');
            s_pop_state <= '0';

            s_pop_synchronizer_s1 <= (others => '0');
            s_pop_synchronizer_s2 <= (others => '0');

            s_pop_gray_pointer_delay <= (others => '0');

            data_out <= (others => '0');
        elsif rising_edge(clock_pop) then
            if s_pop_state = '0' then
                --FIFO is empty
                if s_pop_pointer = s_pop_push_pointer then
                    s_pop_state <= '0';
                else
                    s_pop_state <= '1';
                end if;
            else
                --FIFO contains data
                if pop = '1' and s_pop_pointer + 1 = s_pop_push_pointer then
                    s_pop_state <= '0';
                else
                    s_pop_state <= '1';
                end if; 

                if pop = '1' then
                    s_pop_pointer <= s_pop_pointer + 1;
                    data_out <= ram(to_integer(unsigned(s_pop_pointer)));
                else
                    s_pop_pointer <= s_pop_pointer;
                end if;
            end if;

            s_pop_gray_pointer_delay <= s_pop_gray_pointer;

            --meta stable input
            s_pop_synchronizer_s1 <= s_push_gray_pointer_delay;

            --stable 99.9999% of the time
            s_pop_synchronizer_s2 <= s_pop_synchronizer_s1;
        end if;
    end process;

    -- push side of fifo
    full <= s_push_state;

    --binary to gray code -> for use in push controller
    s_push_gray_pointer <= s_push_pointer(data_depth - 1 downto 0) xor ('0' & s_push_pointer(data_depth - 1 downto 1));

    --gray code to binary -> for use in pop controller
    process(s_push_pop_pointer, s_push_synchronizer_s2)
    begin
        s_push_pop_pointer(data_depth - 1) <= s_push_synchronizer_s2(data_depth - 1);

        for I in data_depth - 2 downto 0 loop
            s_push_pop_pointer(I) <= s_push_synchronizer_s2(I) xor s_push_pop_pointer(I + 1);
        end loop;
    end process;

    process(clock_push, reset)
    begin
        if reset = '1' then
            s_push_pointer <= (others => '0');
            s_push_state <= '0';

            s_push_synchronizer_s1 <= (others => '0');
            s_push_synchronizer_s2 <= (others => '0');

            s_push_gray_pointer_delay <= (others => '0');

        elsif rising_edge(clock_push) then
            if s_push_state = '0' then
                --fifo is not full
                if push = '1' and s_push_pointer + 1 = s_push_pop_pointer then
                    s_push_state <= '1';
                else
                    s_push_state <= '0';
                end if;

                if push = '1' then
                    s_push_pointer <= s_push_pointer + 1;
                    ram(to_integer(unsigned(s_push_pointer))) := data_in;
                else
                    s_push_pointer <= s_push_pointer;
                end if;
            else
                --fifo is full
                if s_push_pointer = s_push_pop_pointer then
                    s_push_state <= '1';
                else
                    s_push_state <= '0';
                end if;
            end if;

            s_push_gray_pointer_delay <= s_push_gray_pointer;

            --meta stable input
            s_push_synchronizer_s1 <= s_pop_gray_pointer_delay;

            --stable 99.9999% of the time
            s_push_synchronizer_s2 <= s_push_synchronizer_s1;
        end if;
    end process;

end rtl;