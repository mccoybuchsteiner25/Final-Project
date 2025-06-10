----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: AXI stream wrapper for controlling I2S audio data flow
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;                                        
----------------------------------------------------------------------------
-- Entity definition
entity fir_wrapper is
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
end fir_wrapper;
----------------------------------------------------------------------------
architecture Behavioral of fir_wrapper is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
constant AC_DATA_WIDTH : integer := 24; 
constant DDS_PHASE_WIDTH : integer := 15;      

signal lrclk_s           : std_logic := '0';
signal s_axis_aclk_s      : std_logic := '0';
signal right_audio_data_o : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal left_audio_data_o : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal m00_axis_tstrb_s : std_logic_vector((M_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
signal m00_axis_tlast_s : std_logic := '0';
signal s00_axis_tstrb_s : std_logic_vector((S_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
signal s00_axis_tlast_s : std_logic := '0';

signal s_axis_data_tready_s : std_logic := '1';

--final project signals 
signal left_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal left_audio_data_rx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_rx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal left_audio_data_valid_o_s : std_logic;
signal right_audio_data_valid_o_s : std_logic;
signal lpf_fir_valid_left_s : std_logic;
signal lpf_fir_valid_right_s : std_logic;
signal lpf_fir_data_right_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal lpf_fir_data_left_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

signal rms_output : unsigned(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal beat : std_logic;
----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------

---------------------------------------------------------------------------- 
-- LPF FIR 
COMPONENT fir_compiler_lpf
  PORT (
    aclk                 : IN  STD_LOGIC;
    s_axis_data_tvalid  : IN  STD_LOGIC;
    s_axis_data_tready  : OUT STD_LOGIC;
    s_axis_data_tdata   : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
    m_axis_data_tvalid  : OUT STD_LOGIC;
    m_axis_data_tready  : IN  STD_LOGIC;
    m_axis_data_tdata   : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

--RMS 
component RMS is
    Generic (
        AC_DATA_WIDTH       : integer := 24;
        AUDIO_DATA_WIDTH    : integer := 24;
        FIFO_DEPTH          : integer := 32);
    Port (
        -- Ports of Axi Responder Bus Interface S00_AXIS
		aclk              : in std_logic;

		s00_axis_tready   : out std_logic;
		s00_axis_tvalid   : in std_logic;

        
        left_data_in        : in std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
        square_root_out     : out unsigned(AC_DATA_WIDTH-1 downto 0));
end component;
---------------------------------------------------------------------------- 
-- AXI stream transmitter
component axis_transmitter is
	generic (
		AUDIO_DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24
	);
	port (
	   lrclk_i : in std_logic;
	   left_audio_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   right_audio_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   

		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((AUDIO_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic
	);
end component axis_transmitter;

---------------------------------------------------------------------------- 
-- AXI stream receiver 
component axis_receiver is
	generic (
		AUDIO_DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24
	);
	port (
	   lrclk_i : in std_logic;
	   left_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   right_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	  left_audio_data_valid_o : out std_logic;
	   right_audio_data_valid_o : out std_logic;

		-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((AUDIO_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic
	);
end component axis_receiver;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    

---------------------------------------------------------------------------- 
-- AXI stream transmitter
transmitter : axis_transmitter
    generic map (
        AUDIO_DATA_WIDTH => C_AXI_STREAM_DATA_WIDTH,
        AC_DATA_WIDTH => 24
    )
    port map (
        left_audio_data_i => left_audio_data_s,
        right_audio_data_i => right_audio_data_s,
        lrclk_i => lrclk_i,
        m00_axis_aclk => m_axis_aclk,
        m00_axis_aresetn => aresetn_i,
        m00_axis_tvalid => m_axis_tvalid,
        m00_axis_tdata => m_axis_tdata,
        m00_axis_tstrb => m00_axis_tstrb_s,
        m00_axis_tlast => m00_axis_tlast_s,
        m00_axis_tready => m_axis_tready
    );
    

---------------------------------------------------------------------------- 
-- AXI stream receiver
receiver : axis_receiver
    generic map (
        AUDIO_DATA_WIDTH => C_AXI_STREAM_DATA_WIDTH,
        AC_DATA_WIDTH => 24
    )
    port map (
        lrclk_i => lrclk_i,
        left_audio_data_o => left_audio_data_rx_s,
        right_audio_data_o => right_audio_data_rx_s,
        left_audio_data_valid_o => left_audio_data_valid_o_s,
        right_audio_data_valid_o => right_audio_data_valid_o_s,
        s00_axis_aclk => s_axis_aclk,
        s00_axis_aresetn => aresetn_i,
        s00_axis_tready => s_axis_tready,
        s00_axis_tdata => s_axis_tdata,
        s00_axis_tstrb => s00_axis_tstrb_s,
        s00_axis_tlast => s00_axis_tlast_s,
        s00_axis_tvalid => s_axis_tvalid
    );
---------------------------------------------------------------------------- 
-- rms 
audio_dsp : RMS
    Port map (

		aclk       =>   s_axis_aclk,   

		s00_axis_tready  => open,
		s00_axis_tvalid   => lpf_fir_valid_left_s or lpf_fir_valid_right_s,
		
        
        left_data_in       => lpf_fir_data_left_s,
        square_root_out     => rms_output
        );


---------------------------------------------------------------------------- 
-- LPF FIR 
lowpass_fir_filter_right :  fir_compiler_lpf
  port map (
    aclk                 => s_axis_aclk,
    s_axis_data_tvalid  => right_audio_data_valid_o_s,
    s_axis_data_tready  => s_axis_data_tready_s,
    s_axis_data_tdata   => right_audio_data_rx_s,
    m_axis_data_tvalid  => lpf_fir_valid_right_s,
    m_axis_data_tready  => m_axis_tready,
    m_axis_data_tdata  => lpf_fir_data_right_s
  );

-- LPF FIR 
lowpass_fir_filter_left :  fir_compiler_lpf
  port map (
    aclk                 => s_axis_aclk,
    s_axis_data_tvalid  => left_audio_data_valid_o_s,
    s_axis_data_tready  => s_axis_data_tready_s,
    s_axis_data_tdata   => left_audio_data_rx_s,
    m_axis_data_tvalid  => lpf_fir_valid_left_s,
    m_axis_data_tready  => m_axis_tready,
    m_axis_data_tdata  => lpf_fir_data_left_s
  );	

---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 


clk_proc : process(m_axis_aclk)
begin
if rising_edge(m_axis_aclk) then
    if (lpf_fir_valid_left_s = '1' or lpf_fir_valid_right_s = '1') then
        left_audio_data_s <= lpf_fir_data_left_s;
        right_audio_data_s <= lpf_fir_data_right_s;
    end if;
    rgb_out <= "111111110000000000000000";
--    if to_integer(unsigned(rms_output)) > integer(0.8 * real(2 ** (AC_DATA_WIDTH*2) - 1)) then
--        rgb_out <= "111111110000000000000000";
--    elsif to_integer(unsigned(rms_output)) > integer(0.5 * real(2 ** (AC_DATA_WIDTH*2) - 1)) then
--        rgb_out <= "000000001111111100000000";
--    elsif to_integer(unsigned(rms_output)) > integer(0.3 * real(2 ** (AC_DATA_WIDTH*2) - 1)) then
--        rgb_out <= "000000000000000011111111";
--   else
--        rgb_out <= "000000000000000000000000";
--    end if;
end if;

end process;

--need logic for beat 



----------------------------------------------------------------------------


end Behavioral;