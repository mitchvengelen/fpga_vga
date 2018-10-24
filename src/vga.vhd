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
    signal s_vertical_sync      : std_logic;
    signal s_vertical_counter   : std_logic_vector(11 downto 0);
    signal s_vertical_state     : std_logic_vector(2 downto 0);

    signal s_horizontal_sync : std_logic;
    signal s_horizontal_counter : std_logic_vector(11 downto 0);
    signal s_horizontal_state   : std_logic_vector(2 downto 0);

    signal s_blank              : std_logic;
    signal s_fifo_read          : std_logic;
begin

    --routing signals to I/O
    horizontal_sync <= '1' xor s_horizontal_sync;
    vertical_sync <= '1' xor s_vertical_sync;
    blank <= not s_blank;
    sync <= '1';

    --horizonal sync generator
    --responsible for generating the horizontal timings 
    process(pixel_clock, reset)
        constant horizontal_front_porch : std_logic_vector(11 downto 0) := "000000010000";
        constant horizontal_sync        : std_logic_vector(11 downto 0) := "000001100000";
        constant horizontal_back_porch  : std_logic_vector(11 downto 0) := "000000110000";
        constant horizontal_pixels      : std_logic_vector(11 downto 0) := "001010000000";  
    begin
        if reset = '1' then
            s_horizontal_state <= "00";
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
            s_vertical_state <= "00";
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
    process(pixel_clock, s_horizontal_state, s_vertical_state)
    begin
        if rising_edge(pixel_clock) then
            if (s_horizontal_state = "000") or (s_horizontal_state = "001") or (s_horizontal_state = "010") or (s_vertical_state = "000") or (s_vertical_state = "001") or (s_vertical_state = "010") then
                s_blank <= '1';
            else
                s_blank <= '0';
            end if;
        end if;
    end process;

    --controll of pixel buffer
    --reading of fifo is delayed by 1 in reference to blank
    process(pixel_clock, s_horizontal_state, s_vertical_state)
    begin
        if rising_edge(pixel_clock) then
            if s_blank = '1' then
                s_fifo_read <= '1';
            else
                s_fifo_read <= '0';
            end if;
        end if;
    end process;
end rtl;