----------------------------------------------------------------------------------
-- Create Date: 21:12:48 05/06/2010 
-- Module Name: UART - Behavioral
-- Used TAB of 4 Spaces
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart is
generic (
	CLK_FREQ	: integer := 50;		-- Main frequency (MHz)
	SER_FREQ	: integer := 9600		-- Baud rate (bps)
);
port (
	-- Control
	clk			: in	std_logic;		-- Main clock
	rst			: in	std_logic;		-- Main reset
	-- External Interface
	rx			: in	std_logic;		-- RS232 received serial data
	tx			: out	std_logic;		-- RS232 transmitted serial data
	-- uPC Interface
	tx_req		: in	std_logic;						-- Request SEND of data
	tx_end		: out	std_logic;						-- Data SENDED
	tx_data		: in	std_logic_vector(7 downto 0);	-- Data to transmit
	rx_ready	: out	std_logic;						-- Received data ready to uPC read
	rx_data		: out	std_logic_vector(7 downto 0)	-- Received data 
);
end uart;

architecture Behavioral of uart is

	-- Constants
	constant uart_idle	:	std_logic := '1';
	constant uart_start	:	std_logic := '0';

	-- Types
	type state is (idle,data,stop1,stop2);

	-- Signals
	signal rx_fsm			:	state;
	signal tx_fsm			:	state;
	signal clock_en		:	std_logic;

	-- Data Temp
	signal data_cnt_tx	:	std_logic_vector(2 downto 0) := "000";
	signal data_cnt_rx	:	std_logic_vector(2 downto 0) := "000";
	signal rx_data_tmp	:	std_logic_vector(7 downto 0);
	signal tx_data_tmp	:	std_logic_vector(7 downto 0);

begin

	clock_manager:process(clk)
		variable counter	:	integer range 0 to conv_integer((CLK_FREQ*1_000_000)/SER_FREQ-1);
	begin
		if clk'event and clk = '1' then
			-- Normal Operation
			if counter = (CLK_FREQ*1_000_000)/SER_FREQ-1 then
				clock_en		<= '1';
				counter		:= 0;
			else
				clock_en		<= '0';
				counter		:= counter + 1;
			end if;
			-- Reset condition
			if rst = '1' then
				counter		:=	0;
			end if;
		end if;
	end process;

	tx_proc:process(clk)
		variable data_cnt	: std_logic_vector(2 downto 0);
	begin
		if clk'event and clk = '1' then
			if clock_en = '1' then
				-- Default values
				tx_end					<= '0';
				tx							<= uart_idle;
				-- FSM description
				case tx_fsm is
					-- Wait to transfer data
					when idle =>
						-- Send Init Bit
						if tx_req = '1' then
							tx				<= uart_start;
							tx_data_tmp	<=	tx_data;
							tx_fsm		<= data;
							data_cnt_tx	<=	(others=>'1');
						end if;
					-- Data receive
					when data =>
						tx					<= tx_data_tmp(0);
						if data_cnt_tx = 0 then
							tx_fsm		<=	stop1;
							data_cnt_tx	<=	(others=>'1');
						else
							tx_data_tmp	<=	'0' & tx_data_tmp(7 downto 1);
							data_cnt_tx	<=	data_cnt_tx - 1;							
						end if;
					-- End of communication
					when stop1 =>
						-- Send Stop Bit
						tx					<= uart_idle;
						tx_fsm			<=	stop2;
					when stop2 =>
						-- Send Stop Bit
						tx_end			<= '1';
						tx					<= uart_idle;
						tx_fsm			<=	idle;
					-- Invalid States
					when others => null;
				end case;
				-- Reset condition
				if rst = '1' then
					tx_fsm				<=	idle;
					tx_data_tmp			<= (others=>'0');
				end if;
			end if;
		end if;
	end process;

	rx_proc:process(clk)
	begin
		if clk'event and clk = '1' then
			if clock_en = '1' then
				-- Default values
				rx_ready			<= '0';
				-- FSM description
				case rx_fsm is
					-- Wait to transfer data
					when idle =>
						if rx = uart_start then
							rx_fsm		<=	data;
						end if;
						data_cnt_rx		<=	(others=>'0');
					-- Data receive
					when data =>
						if data_cnt_rx = 7 then
							rx_fsm		<=	idle;
							rx_ready		<= '1';
							rx_data(7)	<=	rx;
							for i in 0 to 6 loop
								rx_data(i)	<= rx_data_tmp(6-i);
							end loop;
						else
							rx_data_tmp	<=	rx_data_tmp(6 downto 0) & rx;
							data_cnt_rx	<=	data_cnt_rx + 1;
						end if;
					when others => null;
				end case;
				-- Reset condition
				if rst = '1' then
					rx_fsm			<=	idle;
					rx_ready			<= '0';
					rx_data			<= (others=>'0');
					data_cnt_rx		<= (others=>'0');
				end if;
			end if;
		end if;
	end process;

end Behavioral;

