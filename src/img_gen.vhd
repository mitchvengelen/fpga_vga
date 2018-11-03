library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity img_gen is
	port(
		clk : in std_logic;
		rst : in std_logic;
		wrfull : in std_logic;
		
		r : out std_logic_vector(7 downto 0);
		g : out std_logic_vector(7 downto 0);
		b : out std_logic_vector(7 downto 0);
		
		wrreq : out std_logic
	);
end entity;

architecture rtl of img_gen is
	signal s_h_count : std_logic_vector(9 downto 0);
	signal s_state : std_logic_vector(1 downto 0);
begin

	wrreq <= not wrfull;
	
	process(clk,rst,wrfull)
	begin
		if rst = '1' then
			s_h_count <= "0000000000";
			s_state <= "00";
		elsif rising_edge(clk) then
			if wrfull = '0' then
				if s_h_count = 639 then
					s_h_count <= "0000000000";
					s_state <= s_state + 1;
				else
					s_h_count <= s_h_count + 1;
				end if;
			end if;
		end if;
		
			case s_state is
			when "00" =>
				if s_h_count < 320 then
					r <="11111111";
					g <="00000000";
					b <="00000000";
				elsif s_h_count < 480 then
					r <="00000000";
					g <="00000000";
					b <="00000000";
				else
					r <="11111111";
					g <="00000000";
					b <="00000000";
				end if;
			when "01" =>
				if s_h_count < 320 then
					r <="00000000";
					g <="11111111";
					b <="00000000";
				elsif s_h_count < 480 then
					r <="00000000";
					g <="00000000";
					b <="00000000";
				else
					r <="00000000";
					g <="11111111";
					b <="00000000";
				end if;
			when "10" =>
				if s_h_count < 320 then
					r <="00000000";
					g <="00000000";
					b <="11111111";
				elsif s_h_count < 480 then
					r <="00000000";
					g <="00000000";
					b <="00000000";
				else
					r <="00000000";
					g <="00000000";
					b <="11111111";
				end if;
			when "11" =>
				if s_h_count < 320 then
					r <="11111111";
					g <="11111111";
					b <="11111111";
				elsif s_h_count < 480 then
					r <="00000000";
					g <="00000000";
					b <="00000000";
				else
					r <="11111111";
					g <="11111111";
					b <="11111111";
				end if;
			when others =>
			end case;
			
	end process;
	
end architecture;