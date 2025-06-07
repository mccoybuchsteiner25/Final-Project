----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for FIFO --> FIFO AXI stream passthrough
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity tb_rms is
end tb_rms;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture testbench of tb_rms is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Constants
constant AUDIO_DATA_WIDTH : integer := 32;        -- 32-bit AXI data bus
constant AXI_FIFO_DEPTH : integer := 12;        -- AXI stream FIFO depth
constant CLOCK_PERIOD : time := 8ns;            -- 125 MHz clock

-- Signal declarations
signal clk, aresetn, tlast, tvalid, tready : std_logic := '0';
signal tstrb : std_logic_vector((AUDIO_DATA_WIDTH/8)-1 downto 0);
signal left_data_in_s, right_data_in_s : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');

signal testnum : integer := 0;


----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
component RMS is 
Generic (
        AC_DATA_WIDTH       : integer := 24;
        AUDIO_DATA_WIDTH    : integer := 32;
        FIFO_DEPTH          : integer := 32);
    Port (
        -- Ports of Axi Responder Bus Interface S00_AXIS
		aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tstrb    : in std_logic_vector((AUDIO_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;
        
        left_data_in        : in std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
        right_data_in       : in std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0));
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
 uut : RMS
 port map (
        aclk  =>    clk,
		s00_axis_aresetn  =>  aresetn,
		s00_axis_tready   =>  tready,
		s00_axis_tstrb    =>  tstrb,
		s00_axis_tlast    =>  tlast,
		s00_axis_tvalid  =>   tvalid,
        
        left_data_in       =>  left_data_in_s,
        right_data_in      =>  right_data_in_s);
  

----------------------------------------------------------------------------   
-- Clock Generation Processes
----------------------------------------------------------------------------  

-- Generate 100 MHz ADC clock      
adc_clock_gen_process : process
begin
	clk <= '0';				-- start low
	wait for CLOCK_PERIOD;	    -- wait for one CLOCK_PERIOD
	
	loop							-- toggle, wait half a clock period, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process adc_clock_gen_process;



----------------------------------------------------------------------------   
-- Stimulus
----------------------------------------------------------------------------  
stim_proc : process
begin
-- Initialize

tready <= '0';  -- FIFO 1 M_AXIS receiver (testbench to DUT) not ready
testnum <= 0;
tvalid <= '0';

-- Asynchronous reset
aresetn <= '0';
wait for 55 ns;
aresetn <= '1';

left_data_in_s <= x"00000010";  -- 0.0
right_data_in_s <= x"00000001"; -- 0.0
wait for CLOCK_PERIOD;
tvalid <= '1';
wait until rising_edge(clk);
tvalid <= '0';

wait for CLOCK_PERIOD*1000;

wait;


--std.env.stop;

end process stim_proc;

----------------------------------------------------------------------------

end testbench;