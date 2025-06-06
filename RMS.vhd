----------------------------------------------------------------------------
--  Final Project
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: McCoy Buchsteiner
----------------------------------------------------------------------------
--	Description: AXI transmitter 
----------------------------------------------------------------------------
-- Libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
----------------------------------------------------------------------------

-- Entity definition
entity RMS is
    Generic (
        AC_DATA_WIDTH       : integer := 24;
        AUDIO_DATA_WIDTH    : integer := 32;
        FIFO_DEPTH          : integer := 30);
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
end RMS;

----------------------------------------------------------------------------
architecture Behavioral of RMS is
----------------------------------------------------------------------------

-- RMS Signals
signal square_valid_out, add_valid_out, subtract_valid_out, divide_valid_out, square_root_valid_out : std_logic := '0';

signal square_data_ready, add_data_ready, subtract_data_ready, divide_data_ready, square_root_data_ready : std_logic := '0';

signal left_square_data, right_square_data : signed((2*AC_DATA_WIDTH)-1 downto 0) := (others => '0');

signal accumulator : signed(99 downto 0) := (others => '0');

-- FIFO Signals
signal wr_en_s, rd_en_s     : std_logic := '0';
signal wr_data_s, rd_data_s : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
signal empty_s, full_s      : std_logic := '0';

-- FSM Signals
type state_type is (Idle, Square_Newest_Sample, Add_Newest_Sample, Remove_Oldest_Sample, Calculate_Average, Extract_Square_Root);
signal curr_state, next_state : state_type := Idle;

---------------------------------------------------------------------------- 

-- FIFO for accumulator
component fifo is
    Generic (
		FIFO_DEPTH : integer := 30;
        DATA_WIDTH : integer := 24);
    Port ( 
        clk_i       : in std_logic;
        reset_i     : in std_logic;
        
        -- Write channel
        wr_en_i     : in std_logic;
        wr_data_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Read channel
        rd_en_i     : in std_logic;
        rd_data_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Status flags
        empty_o         : out std_logic;
        full_o          : out std_logic);   
end component fifo;

---------------------------------------------------------------------------- 
begin
---------------------------------------------------------------------------- 

fifo_inst : fifo 
    generic map(
        FIFO_DEPTH => FIFO_DEPTH,
        DATA_WIDTH => AC_DATA_WIDTH)
    port map (
        clk_i => aclk,
        reset_i => not s00_axis_aresetn,
        
        wr_en_i => wr_en_s,
        wr_data_i => wr_data_s,
        
        rd_en_i => rd_en_s,
        rd_data_o => rd_data_s,
        
        empty_o => empty_s,
        full_o => full_s);

---------------------------------------------------------------------------- 

-- Square Sample
square_sample : process(square_data_ready)
begin
    if square_data_ready = '1' then
        left_square_data <= signed(left_data_in(AC_DATA_WIDTH-1 downto 0)) * signed(left_data_in(AC_DATA_WIDTH-1 downto 0));
        
        right_square_data <= signed(right_data_in(AC_DATA_WIDTH-1 downto 0)) * signed(right_data_in(AC_DATA_WIDTH-1 downto 0));
    end if;
end process square_sample;

---------------------------------------------------------------------------- 

---- Add Sample
--add_sample : process(add_data_ready)
--begin
--    if add_data_ready = '1' then
--        accumulator <= accumulator + left_square_data + right_square_data;
--        wr_data_s <= std_logic_vector(left_square_data);
--        write_en <= '1';
        
        
---------------------------------------------------------------------------- 

-- Next State Logic
next_state_logic : process(curr_state, aclk)
begin
    next_state <= curr_state;
    
    case curr_state is 
        
                when Idle => 
                    if s00_axis_tvalid = '1' then
                        next_state <= Square_Newest_Sample;
                    end if;
                    
                when Square_Newest_Sample => 
                    if square_valid_out = '1' then
                        next_state <= Add_Newest_Sample;
                    end if;
                
                when Add_Newest_Sample => 
                    if add_valid_out = '1' then
                        next_state <= Remove_Oldest_Sample;
                    end if;
                
                when Remove_Oldest_Sample => 
                    if subtract_valid_out = '1' then
                        next_state <= Calculate_Average;
                    end if;
                
                when Calculate_Average => 
                    if divide_valid_out = '1' then
                        next_state <= Extract_Square_Root;
                    end if;
                
                when Extract_Square_Root => 
                    if square_root_valid_out = '1' then
                        next_state <= Idle;
                    end if;
                      
                when others => 
                    next_state <= Idle;
        end case;
end process;

---------------------------------------------------------------------------- 

-- State Output Logic
fsm_output_logic : process(curr_state)
begin
        case curr_state is 
        
            when Idle =>
            
            when Square_Newest_Sample => 
                square_data_ready <= '1';
                
            when Add_Newest_Sample => 
            
            when Remove_Oldest_Sample =>
            
            when Calculate_Average => 
            
            when Extract_Square_Root =>
            
        end case;

end process fsm_output_logic;
      
---------------------------------------------------------------------------- 
end Behavioral;