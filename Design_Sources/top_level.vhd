----------------------------------------------------------------------------
--  Final Project
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: McCoy Buchsteiner & Nick Hepburn
----------------------------------------------------------------------------
--	Description: Top-level file for audio codec tone generator and data passthrough 
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;
----------------------------------------------------------------------------

-- Entity definition
entity top_level is
generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4;
		C_S_AXI_DATA_WIDTH	    : integer	:= 32;
		C_S_AXI_ADDR_WIDTH	    : integer	:= 4;
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;

		AC_DATA_WIDTH           : integer   := 24);
    Port (
        -- Fabric clock from Zynq PS
		sysclk_i  : in  STD_LOGIC;	
		
		-- Audio Codec I2S controls
		ac_mute_en_i    : in STD_LOGIC;
        ac_bclk_o       : out STD_LOGIC;
        ac_mclk_o       : out STD_LOGIC;
        ac_mute_n_o     : out STD_LOGIC;	-- Active Low
        
        -- Audio Codec DAC (audio out)
        ac_dac_data_o   : out STD_LOGIC;
        ac_dac_lrclk_o  : out STD_LOGIC;
        
        -- Audio Codec ADC (audio in)
        ac_adc_data_i   : in STD_LOGIC;
        ac_adc_lrclk_o  : out STD_LOGIC;

		----------------------------------------------------------------------------
        
        -- AXI Stream Interface (Receiver/Responder)
    	-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;
		
		----------------------------------------------------------------------------

        -- AXI Stream Interface (Tranmitter/Controller)
		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic);
        
end top_level;

----------------------------------------------------------------------------
architecture Behavioral of top_level is
----------------------------------------------------------------------------

signal left_audio_data_s, right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

signal mclk_s, bclk_s, lrclk_s : std_logic := '0';

signal ac_mute_n_s, ac_mute_n_reg_s : std_logic := '0';

-- FIR signals 
signal lpf_fir_data_left_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal lpf_fir_data_right_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

signal lpf_fir_left_valid_s : std_logic := '0';
signal lpf_fir_right_valid_s : std_logic := '0';


----------------------------------------------------------------------------

-- Clock generation
component i2s_clock_gen is
    Port (
		--sysclk_125MHz_i   : in  std_logic; -- comment out for block design
		mclk_i            : in std_logic;
		
		-- Forwarded clocks
		mclk_fwd_o		  : out std_logic;	
		bclk_fwd_o        : out std_logic;
		adc_lrclk_fwd_o   : out std_logic;
		dac_lrclk_fwd_o   : out std_logic;

        -- Clocks for I2S components
		mclk_o		      : out std_logic; -- comment our for block design
		bclk_o            : out std_logic;
		lrclk_o           : out std_logic);  
end component;

----------------------------------------------------------------------------

-- I2S receiver
component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		adc_serial_data_i     : in std_logic);  
end component; 

----------------------------------------------------------------------------

-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end component; 

----------------------------------------------------------------------------

-- AXI stream transmitter
component axis_transmitter is
    Generic (
        AC_DATA_WIDTH         : integer := 24;
        AUDIO_DATA_WIDTH      : integer := 32);
    Port (
        -- Timing
		lrclk_i               : in std_logic;
		
		-- M
		m00_axis_aclk         : in std_logic;
		m00_axis_aresetn      : in std_logic;
		m00_axis_tready       : in std_logic;
		m00_axis_tdata        : out std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
		m00_axis_tlast        : out std_logic;
		m00_axis_tstrb        : out std_logic_vector(3 downto 0);
		m00_axis_tvalid       : out std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0));  
end component;

----------------------------------------------------------------------------

-- LPF FIR 
component fir_compiler_lpf
    PORT (
        aclk                : IN  STD_LOGIC;
        s_axis_data_tvalid  : IN  STD_LOGIC;
        s_axis_data_tready  : OUT STD_LOGIC;
        s_axis_data_tdata   : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid  : OUT STD_LOGIC;
        m_axis_data_tready  : IN  STD_LOGIC;
        m_axis_data_tdata   : OUT STD_LOGIC_VECTOR(23 DOWNTO 0) );
END COMPONENT;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------

-- Clock generation
clock_gen : i2s_clock_gen
    port map (
        --sysclk_125MHz_i     => sysclk_i, -- comment out for block design
        mclk_i              => sysclk_i, -- comment out for simulation
        
        mclk_fwd_o          => ac_mclk_o,
        bclk_fwd_o          => ac_bclk_o,
        adc_lrclk_fwd_o     => ac_adc_lrclk_o,
        dac_lrclk_fwd_o     => ac_dac_lrclk_o,
        
        mclk_o              => mclk_s,
        bclk_o              => bclk_s,
        lrclk_o             => lrclk_s);


---------------------------------------------------------------------------- 

-- I2S receiver
receiver_i2s : i2s_receiver 
    generic map (AC_DATA_WIDTH => AC_DATA_WIDTH)
    port map (

        -- Timing
		mclk_i                => mclk_s, 	
		bclk_i                => bclk_s,	
		lrclk_i               => lrclk_s,
		
		-- Data
		adc_serial_data_i     => ac_adc_data_i,
		left_audio_data_o     => left_audio_data_s,
		right_audio_data_o    => right_audio_data_s);
	
---------------------------------------------------------------------------- 

-- I2S transmitter
transmitter_i2s : i2s_transmitter
    generic map (AC_DATA_WIDTH => AC_DATA_WIDTH)
    port map (

        -- Timing
		mclk_i                => mclk_s, 	
		bclk_i                => bclk_s,	
		lrclk_i               => lrclk_s,
		
		-- Data
		dac_serial_data_o     => ac_dac_data_o,
		left_audio_data_i     => left_audio_data_s,
		right_audio_data_i    => right_audio_data_s);

---------------------------------------------------------------------------- 

-- AXI stream transmitter
transmitter_axis : axis_transmitter
    generic map (
        AC_DATA_WIDTH         => AC_DATA_WIDTH,
        AUDIO_DATA_WIDTH      => C_AXI_STREAM_DATA_WIDTH)
    port map (
        -- Timing
		lrclk_i               => lrclk_s,
		
		-- M
		m00_axis_aclk         => m00_axis_aclk, 
		m00_axis_aresetn      => m00_axis_aresetn,
		m00_axis_tready       => m00_axis_tready,
		m00_axis_tdata        => m00_axis_tdata,
		m00_axis_tlast        => m00_axis_tlast,
		m00_axis_tstrb        => m00_axis_tstrb,
		m00_axis_tvalid       => m00_axis_tvalid,
		
		-- Data
		left_audio_data_i     => left_audio_data_s,
		right_audio_data_i    => right_audio_data_s);

---------------------------------------------------------------------------- 

------ Left LPF FIR 
--lowpass_fir_filter_left :  fir_compiler_lpf
--  port map (
--    aclk                => m00_axis_aclk,
--    s_axis_data_tvalid  => m00_axis_tvalid,
--    s_axis_data_tready  => s_axis_data_tready_s,
--    s_axis_data_tdata   => left_audio_data_s,
--    m_axis_data_tvalid  => lpf_fir_left_valid_s,
--    m_axis_data_tready  => m_axis_tready,
--    m_axis_data_tdata   => lpf_fir_data_left_s);
  
---------------------------------------------------------------------------- 
-- Logic
----------------------------------------------------------------------------

ac_mute_n_s <= not ac_mute_en_i;
ac_mute_n_o <= ac_mute_n_reg_s;

----------------------------------------------------------------------------

mute_process : process(sysclk_i)
begin
    if rising_edge(sysclk_i) then
        ac_mute_n_reg_s <= ac_mute_n_s;
    end if;
end process mute_process;

---------------------------------------------------------------------------- 
end Behavioral;
