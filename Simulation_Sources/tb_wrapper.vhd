----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for AXI stream interface of I2S controller
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

----------------------------------------------------------------------------
-- Entity Declaration
entity tb_wrapper is
end tb_wrapper;

----------------------------------------------------------------------------
architecture testbench of tb_wrapper is
----------------------------------------------------------------------------
constant AC_DATA_WIDTH : integer := 24; 
constant M_AXI_DATA_WIDTH : integer := 32;
constant S_AXI_DATA_WIDTH : integer := 32;
-- Constants
constant AXIS_DATA_WIDTH : integer := 32;        -- AXI stream data bus
constant AXIS_FIFO_DEPTH : integer := 12; 
constant CLOCK_PERIOD : time := 10ns;            -- 100 MHz system clock period
constant MCLK_PERIOD : time := 81.38 ns;        -- 12.288 MHz MCLK
constant SAMPLING_FREQ  : real := 4800000.00;     -- 48 kHz sampling rate
constant T_SAMPLE : real := 1.0/SAMPLING_FREQ;
constant AUDIO_DATA_WIDTH : integer := 24;
--AXI 
constant REG_DATA_WIDTH : integer := 4;
constant C_S00_AXI_DATA_WIDTH : integer := 32;
constant C_S00_AXI_ADDR_WIDTH : integer := 4;
constant SINE_FREQ : real := 1000000.0;
constant SINE_AMPL  : real := real(2**(AUDIO_DATA_WIDTH-1)-1);
----------------------------------------------------------------------------------
signal sine_data, sine_data_tx : std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
----------------------------------------------------------------------------------
signal data_out : std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal data_select : std_logic_vector(C_S00_AXI_ADDR_WIDTH-3 downto 0);
signal axi_reg : integer := 0;
signal bit_count : integer;

signal rms : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal rgb : std_logic_vector(23 downto 0);

----------------------------------------------------------------------------

-- Signals to hook up to DUT
signal clk : std_logic := '0';
signal mclk_s, bclk_s, lrclk_s : std_logic := '0';
signal mute_en_sw : std_logic;
signal mute_n, bclk, mclk, data_in, lrclk : std_logic;

----------------------------------------------------------------------------

-- Testbench signals

signal reset_n : std_logic := '1';
signal enable_stream : std_logic := '0';
signal test_num : integer := 0;

----------------------------------------------------------------------------

--AXI FIFO signal
signal s_tready_s : std_logic;
signal s_tvalid_s : std_logic;

signal m_tready_s : std_logic;
signal m_tvalid_s :std_logic;

----------------------------------------------------------------------------

-- AXI Stream
signal M_AXIS_TDATA, S_AXIS_TDATA : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
signal M_AXIS_TSTRB, S_AXIS_TSTRB : std_logic_vector((AXIS_DATA_WIDTH/8)-1 downto 0);
signal M_AXIS_TVALID, S_AXIS_TVALID : std_logic := '0';
signal M_AXIS_TREADY, S_AXIS_TREADY : std_logic := '0';
signal M_AXIS_TLAST, S_AXIS_TLAST : std_logic := '0';

----------------------------------------------------------------------------
--components

----------------------------------------------------------------------------
component fir_wrapper is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		M_AXI_DATA_WIDTH : integer := 32;
		S_AXI_DATA_WIDTH : integer := 32;
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_DATA_WIDTH : integer := 32;
        C_S00_AXI_ADDR_WIDTH : integer := 4
	);
    Port ( 
        ----------------------------------------------------------------------------
        -- clocks 
        lrclk_i : in std_logic;
       	
        --reset 
        aresetn_i : in std_logic; 

        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	s_axis_aclk : in std_logic;
    	s_axis_tdata : in std_logic_vector(S_AXI_DATA_WIDTH-1 downto 0);
    	s_axis_tvalid : in std_logic;
    	s_axis_tready : out std_logic;
    	
    	m_axis_aclk : in std_logic;
    	m_axis_tready : in std_logic;
    	m_axis_tvalid : out std_logic;
    	m_axis_tdata : out std_logic_vector(M_AXI_DATA_WIDTH-1 downto 0);
		
		rgb_out : out std_logic_vector(23 downto 0)
		);
end component;

----------------------------------------------------------------------------
component i2s_clock_gen is
    Port ( 
          --sysclk_125MHz_i   : in std_logic;        --comment out for block design
          mclk_i            : in std_logic;        -- comment out for simulation
          mclk_fwd_o        : out std_logic;  
          bclk_fwd_o        : out std_logic;
          adc_lrclk_fwd_o   : out std_logic;
          dac_lrclk_fwd_o   : out std_logic;
        
     --   mclk_o    : out std_logic; -- 12.288 MHz output of clk_wiz	
		  bclk_o    : out std_logic;	
		  lrclk_o   : out std_logic); 
end component;




----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
uut : fir_wrapper
    port map (
         -- clocks 
        lrclk_i => lrclk_s,
       	
        --reset 
        aresetn_i  => reset_n,

        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	s_axis_aclk  => clk,
    	s_axis_tdata => sine_data,
    	s_axis_tvalid => s_tvalid_s,
    	s_axis_tready => s_tready_s,
    	
    	m_axis_aclk => clk,
    	m_axis_tready => m_tready_s,
    	m_axis_tvalid => m_tvalid_s,
    	m_axis_tdata => data_out,
		
		rgb_out => rgb
    );

----------------------------------------------------------------------------
clocking : i2s_clock_gen
    Port map ( 
          --sysclk_125MHz_i   : in std_logic;        --comment out for block design
          mclk_i            => mclk,
          mclk_fwd_o          => open,
          bclk_fwd_o         => open,
          adc_lrclk_fwd_o    => open,
          dac_lrclk_fwd_o    => open,
        
--          mclk_o     => mclk,
		  bclk_o     =>	bclk,
		  lrclk_o    =>   lrclk_s); 


----------------------------------------------------------------------------



----------------------------------------------------------------------------


----------------------------------------------------------------------------



---------------------------------------------------------------------------- 
 
-- Hook up transmitter interface to receiver (passthrough test)   
--S_AXIS_TDATA <= M_AXIS_TDATA;
--S_AXIS_TSTRB <= M_AXIS_TSTRB;
--S_AXIS_TLAST <= M_AXIS_TLAST;
--S_AXIS_TVALID <= M_AXIS_TVALID;
--M_AXIS_TREADY <= S_AXIS_TREADY;

----------------------------------------------------------------------------   
-- Processes
----------------------------------------------------------------------------   
--M_AXIS_TREADY <= '1';

-- Generate clock        
clock_gen_process : process
begin
	clk <= '0';				-- start low
	wait for CLOCK_PERIOD/2;		-- wait for half a clock period
	loop							-- toggle, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;

mclock_gen_process : process
begin
	mclk <= '0';				-- start low
	wait for MCLK_PERIOD/2;		-- wait for half a clock period
	loop							-- toggle, and loop
	  mclk <= not(clk);
	  wait for MCLK_PERIOD/2;
	end loop;
end process mclock_gen_process;
----------------------------------------------------------------------------
-- Generate input data (stimulus)
----------------------------------------------------------------------------
generate_audio_data: process
    variable t : real := 0.0;
begin		
----------------------------------------------------------------------------
-- Loop forever	
loop	
----------------------------------------------------------------------------
-- Progress one sample through the sine wave:
sine_data <= std_logic_vector(to_signed(integer(SINE_AMPL*sin(math_2_pi*SINE_FREQ*t) ), S_AXI_DATA_WIDTH));

----------------------------------------------------------------------------
-- Take sample
wait until lrclk = '1';
sine_data_tx <= std_logic_vector(unsigned(not(sine_data(S_AXI_DATA_WIDTH-1)) & sine_data(S_AXI_DATA_WIDTH-2 downto 0)));

----------------------------------------------------------------------------
-- Transmit sample to right audio channel
----------------------------------------------------------------------------
bit_count <= AUDIO_DATA_WIDTH-1;            -- Initialize bit counter, send MSB first
for i in 0 to AUDIO_DATA_WIDTH-1 loop
    wait until bclk = '0';
    data_in <= sine_data_tx(bit_count-i);     -- Set input data
end loop;

data_in <= '0';
bit_count <= AUDIO_DATA_WIDTH-1;            -- Reset bit counter to MSB

----------------------------------------------------------------------------
--Transmit sample to left audio channel
----------------------------------------------------------------------------
wait until lrclk = '0';
for i in 0 to AUDIO_DATA_WIDTH-1 loop
    wait until bclk = '0';
    data_in <= sine_data_tx(bit_count-i);     -- Set input data
end loop;
data_in <= '0';

----------------------------------------------------------------------------						
--Increment by one sample
t := t + T_SAMPLE;
end loop;
    
end process generate_audio_data;




 
----------------------------------------------------------------------------
-- Testbench Stimulus
----------------------------------------------------------------------------
stimulus : PROCESS
 BEGIN
    -- Initialize, reset
    s_tready_s <= '1';
    s_tvalid_s <= '1';
    
    m_tready_s <= '1';
    
    wait for CLOCK_PERIOD*100;
  
  wait;
        
 END PROCESS stimulus;

----------------------------------------------------------------------------
-- Disable mute
mute_en_sw <= '0';


----------------------------------------------------------------------------

end testbench;
