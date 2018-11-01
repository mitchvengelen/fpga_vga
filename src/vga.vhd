library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity vga_controller is
    port(
        -- vga control signals
        enable          : in  std_logic;
        pixel_clock     : in  std_logic;
        reset           : in  std_logic;
        
        -- vga outputs
        horizontal_sync : out std_logic;
        vertical_sync   : out std_logic;
        blank           : out std_logic;
        sync            : out std_logic;
        red_out         : out std_logic_vector(7 downto 0);
        green_out       : out std_logic_vector(7 downto 0);
        blue_out        : out std_logic_vector(7 downto 0);

        -- data signals
        red_in          : in  std_logic_vector(7 downto 0);
        green_in        : in  std_logic_vector(7 downto 0);
        blue_in         : in  std_logic_vector(7 downto 0);
        data_clock      : in  std_logic;
        write_enable    : in  std_logic;
        buffer_full     : out std_logic
    );
end vga_controller;

architecture rtl of vga_controller is
    signal s_vertical_sync          : std_logic;
    signal s_vertical_sync_delay    : std_logic;
    signal s_vertical_counter       : std_logic_vector(11 downto 0);
    signal s_vertical_state         : std_logic_vector(2 downto 0);

    signal s_horizontal_sync        : std_logic;
    signal s_horizontal_sync_delay  : std_logic;
    signal s_horizontal_counter     : std_logic_vector(11 downto 0);
    signal s_horizontal_state       : std_logic_vector(2 downto 0);

    signal s_blank                  : std_logic;
    signal s_fifo_read              : std_logic;
    signal s_empty                  : std_logic;

    signal s_rgb_in                 : std_logic_vector(23 downto 0);
    signal s_rgb_out                : std_logic_vector(23 downto 0);

    component fifo
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
    end component;
begin

    --disabling sync on the DAC
    sync <= '1';

    s_rgb_in(23 downto 0) <= red_in(7 downto 0) & green_in(7 downto 0) & blue_in(7 downto 0);
    red_out(7 downto 0) <= s_rgb_out(23 downto 16);
    green_out(7 downto 0) <= s_rgb_out(15 downto 8);
    blue_out(7 downto 0) <= s_rgb_out(7 downto 0);

    --declaring fifo instance in the design
    u1  : fifo  generic map(data_width => 24, data_depth => 10)
                   port map(push => write_enable,
                            full => buffer_full,
                            clock_push => data_clock,
                            data_in => s_rgb_in,
                            pop => s_fifo_read,
                            empty => s_empty,
                            clock_pop => pixel_clock,
                            data_out => s_rgb_out,
                            reset => reset
                            );

    

    --horizonal sync generator
    --responsible for generating the horizontal timings 
    process(pixel_clock, reset)
        constant horizontal_front_porch : std_logic_vector(11 downto 0) := "000000010000";
        constant horizontal_sync        : std_logic_vector(11 downto 0) := "000001100000";
        constant horizontal_back_porch  : std_logic_vector(11 downto 0) := "000000110000";
        constant horizontal_pixels      : std_logic_vector(11 downto 0) := "001010000000";  
    begin
        if reset = '1' then
            s_horizontal_state <= "000";
            s_horizontal_counter <= X"000";
            s_horizontal_sync <= '0';
        elsif rising_edge(pixel_clock) then
            case s_horizontal_state is
                when "000" =>   --front porch
                    if s_horizontal_counter + 1 < horizontal_back_porch then
                        s_horizontal_state <= "001";
                        s_horizontal_counter <= X"000";
                    else
                        s_horizontal_counter <= s_horizontal_counter + 1;
                    end if;
                    
                    s_horizontal_sync <= '0';

                when "001" =>   --sync
                    if s_horizontal_counter + 1 < horizontal_back_porch then
                        s_horizontal_state <= "010";
                        s_horizontal_counter <= X"000";
                    else
                        s_horizontal_counter <= s_horizontal_counter + 1;
                    end if;

                    s_horizontal_sync <= '1';

                when "010" =>   --back proch
                    if s_horizontal_counter + 1 < horizontal_back_porch then
                        s_horizontal_state <= "011";
                        s_horizontal_counter <= X"000";
                    else
                        s_horizontal_counter <= s_horizontal_counter + 1;
                    end if;

                    s_horizontal_sync <= '0';

                when "011" =>   --visible area
                    if s_horizontal_counter + 2 < horizontal_back_porch then
                        s_horizontal_state <= "100";
                        s_horizontal_counter <= X"000";
                    else
                        s_horizontal_counter <= s_horizontal_counter + 1;
                    end if;
                    
                    s_horizontal_sync <= '0';

                when "100" =>   --end of line
                    s_horizontal_state <= "000";
                    s_horizontal_sync <= '0';

                when others =>
            end case;
        end if;
    end process;

    --vertical sync generator
    --responsible for generating the vertical timings
    process(pixel_clock, reset)
        constant vertical_front_porch : std_logic_vector(11 downto 0) := "000000001010";
        constant vertical_sync        : std_logic_vector(11 downto 0) := "000000000010";
        constant vertical_back_porch  : std_logic_vector(11 downto 0) := "000000100001";
        constant vertical_pixels      : std_logic_vector(11 downto 0) := "000111100000";
    begin
        if reset = '1' then
            s_vertical_state <= "000";
            s_vertical_counter <= X"000";
            s_vertical_sync <= '0';
        elsif rising_edge(pixel_clock) then
            case s_vertical_state is
                when "000" =>   --front porch
                    if s_horizontal_state = "100" then
                        if s_vertical_counter + 1 < vertical_back_porch then
                            s_vertical_state <= "001";
                            s_vertical_counter <= X"000";
                        else
                            s_vertical_counter <= s_vertical_counter + 1;
                        end if;
                    end if;
                    
                    s_vertical_sync <= '0';

                when "001" =>   --sync
                    if s_horizontal_state = "100" then
                        if s_vertical_counter + 1 < vertical_back_porch then
                            s_vertical_state <= "010";
                            s_vertical_counter <= X"000";
                        else
                            s_vertical_counter <= s_vertical_counter + 1;
                        end if;
                    end if;

                    s_vertical_sync <= '1';

                when "010" =>   --back proch
                    if s_horizontal_state = "100" then
                        if s_vertical_counter + 1 < vertical_back_porch then
                            s_vertical_state <= "011";
                            s_vertical_counter <= X"000";
                        else
                            s_vertical_counter <= s_vertical_counter + 1;
                        end if;
                    end if;

                    s_vertical_sync <= '0';

                when "011" =>   --visible area
                    if s_horizontal_state = "100" then
                        if s_vertical_counter + 2 < vertical_back_porch then
                            s_vertical_state <= "100";
                            s_vertical_counter <= X"000";
                        else
                            s_vertical_counter <= s_vertical_counter + 1;
                        end if;
                    end if;
                    
                    s_vertical_sync <= '0';

                when "100" =>   --end of line
                    if s_horizontal_state = "100" then
                        s_vertical_state <= "000";
                    end if;

                    s_vertical_sync <= '0';

                when others =>
            end case;
        end if;
    end process;

    --blank output
    --makes screen black
    --controll of pixel buffer
    --reading of fifo is delayed by 1 in reference to blank
    process(pixel_clock, s_horizontal_state, s_vertical_state)
    begin
        if rising_edge(pixel_clock) then
            --is the system in any syncing phase?
            if (s_horizontal_state = "000") or (s_horizontal_state = "001") or (s_horizontal_state = "010") or (s_vertical_state = "000") or (s_vertical_state = "001") or (s_vertical_state = "010") then
                s_blank <= '1';
                s_fifo_read <= '0';
            else
                s_blank <= '0';
                s_fifo_read <= '1';
            end if;

            --delays blank to match the fifo output
            blank <= not s_blank;

        end if;
    end process;


    --delay of the sync signals to match the blank and fifo outputs
    process(pixel_clock)
    begin
        if rising_edge(pixel_clock) then
            s_horizontal_sync_delay <= s_horizontal_sync;
            s_vertical_sync_delay <= s_vertical_sync;
            horizontal_sync <= '1' xor s_horizontal_sync_delay;
            vertical_sync <= '1' xor s_vertical_sync_delay;
        end if;
    end process;
end rtl;