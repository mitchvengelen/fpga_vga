library ieee;

use ieee.std_logic_1164.all;

entity vga_wrapper is
    port(
            --status signals
            new_frame : in std_logic;
            end_line  : in std_logic;

            --hand shake signals
            valid : in std_logic;
            ready : out std_logic;

            --data I/O
            r_in : in std_logic_vector(7 downto 0);
            g_in : in std_logic_vector(7 downto 0);
            b_in : in std_logic_vector(7 downto 0);

            r_out : out std_logic_vector(7 downto 0);
            g_out : out std_logic_vector(7 downto 0);
            b_out : out std_logic_vector(7 downto 0);

            --display sync signals
            h_sync : out std_logic;
            v_sync : out std_logic;
            blank  : out std_logic;
            sync   : out std_logic;

            --clocking and reset
            clk : in std_logic;
            pixel_clk : in std_logic;
            rst : in std_logic
        );
end vga_wrapper;

architecture rtl of vga_wrapper is
    --component declaration
    component vga_controller is
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
    end component;

    --signal declaration
    signal s_ready : std_logic;

    signal s_valid : std_logic;

begin

    U1 : vga_controller port map(pixel_clock => pixel_clk,
                                 reset => rst,
                                 horizontal_sync => h_sync,
                                 vertical_sync => v_sync,
                                 blank => blank,
                                 sync => sync,
                                 red_out => r_out,
                                 green_out => g_out,
                                 blue_out => b_out,
                                 red_in => r_in,
                                 green_in => g_in,
                                 blue_in => b_in,
                                 data_clock => clk,
                                 write_enable => s_valid,
                                 buffer_full => s_ready
                                );
    --using fifo full as fifo is not full
    --when full turns to 0 so system is not ready

    --converting the signals to proper protocol
    s_valid <= valid and ready;
    ready <= not s_ready;
end architecture;