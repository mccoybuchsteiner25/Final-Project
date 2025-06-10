----------------------------------------------------------------------------
--  Final Project
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: McCoy Buchsteiner & Nick Hepburn
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
        FIFO_DEPTH          : integer := 32);
    Port (
        -- Ports of Axi Responder Bus Interface S00_AXIS
		aclk              : in std_logic;

		s00_axis_tready   : out std_logic;
		s00_axis_tvalid   : in std_logic;
		    
        left_data_in        : in std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
        square_root_out     : out unsigned(AC_DATA_WIDTH-1 downto 0));
end RMS;

----------------------------------------------------------------------------
architecture Behavioral of RMS is
----------------------------------------------------------------------------

-- RMS Signals
signal square_valid_out, add_valid_out, subtract_valid_out, divide_valid_out, square_root_valid_out : std_logic := '0';

signal square_data_ready, add_data_ready, subtract_data_ready, divide_data_ready, square_root_data_ready : std_logic := '0';

signal left_square_data, right_square_data : signed((AC_DATA_WIDTH*2)-1 downto 0) := (others => '0');

signal accumulator : signed((AC_DATA_WIDTH*2)-1 downto 0) := (others => '0');
signal average     : signed((AC_DATA_WIDTH*2)-1 downto 0) := (others => '0');
signal sqrt_result : unsigned(accumulator'length/2 downto 0);

signal subtract : std_logic := '0';
signal r_squared, l_squared : signed(AUDIO_DATA_WIDTH-1 downto 0);

-- FIFO Signals
signal wr_en_s, rd_en_s     : std_logic := '0';
signal wr_data_s, rd_data_s : std_logic_vector((AC_DATA_WIDTH*2)-1 downto 0);
signal empty_s, full_s      : std_logic := '0';

-- FSM Signals
type state_type is (Idle, Square_Newest_Sample, Add_Newest_Sample, Read_Idle, Remove_Oldest_Sample, Calculate_Average, Extract_Square_Root);
signal curr_state, next_state : state_type := Idle;

---------------------------------------------------------------------------- 

-- FIFO for accumulator
component fifo_accum is
    Generic (
		FIFO_DEPTH : integer := 1024;
        DATA_WIDTH : integer := 24);
    Port ( 
        clk_i       : in std_logic;
        reset_i     : in std_logic;
        
        -- Write channel
        wr_en_i     : in std_logic;
        wr_data_i   : in std_logic_vector((2*DATA_WIDTH)-1 downto 0);
        
        -- Read channel
        rd_en_i     : in std_logic;
        rd_data_o   : out std_logic_vector((2*DATA_WIDTH)-1 downto 0);
        
        -- Status flags
        empty_o         : out std_logic;
        full_o          : out std_logic);   
end component fifo_accum;

----------------------------------------------------------------------------
--FUNCTIONS 
----------------------------------------------------------------------------

function approx_sqrt(val : unsigned) return unsigned is
    variable result : unsigned(val'length/2 downto 0) := (others => '0');
    variable temp   : unsigned(val'length-1 downto 0) := val;
begin
    -- Find the most significant '1' and shift right by half
    for i in temp'range loop
        if temp(i) = '1' then
            result := shift_right(temp, i/2)(result'range);
            exit;
        end if;
    end loop;
    return result;
end function;

---------------------------------------------------------------------------- 
begin
---------------------------------------------------------------------------- 
square_root_out <= resize(unsigned(sqrt_result),24);
   
fifo_inst : fifo_accum 
    generic map(
        FIFO_DEPTH => FIFO_DEPTH,
        DATA_WIDTH => AC_DATA_WIDTH)
    port map (
        clk_i => aclk,
        reset_i => '1',
        
        wr_en_i => wr_en_s,
        wr_data_i => wr_data_s,
        
        rd_en_i => rd_en_s,
        rd_data_o => rd_data_s,
        
        empty_o => empty_s,
        full_o => full_s);

---------------------------------------------------------------------------- 

-- Square Sample
--square_sample : process(square_data_ready)
--begin
--    if square_data_ready = '1' then
--        left_square_data <= signed(left_data_in(AC_DATA_WIDTH-1 downto 0)) * signed(left_data_in(AC_DATA_WIDTH-1 downto 0));
        
--        right_square_data <= signed(right_data_in(AC_DATA_WIDTH-1 downto 0)) * signed(right_data_in(AC_DATA_WIDTH-1 downto 0));
        
--        square_valid_out <= '1';
--    else
--        left_square_data <= (others => '0');
--        right_square_data <= (others => '0');
--        square_valid_out <= '0';
--    end if;
--end process square_sample;

------------------------------------------------------------------------------ 

---- Add Sample to accumulator
--add_sample : process(add_data_ready)
--begin

--    if add_data_ready = '1' then
--        accumulator <= accumulator + left_square_data;
        
--        wr_data_s <= std_logic_vector(left_square_data);
--        wr_en_s <= '1';
        
--        add_valid_out <= '1';
--    else
--        accumulator <= accumulator;
--        wr_en_s <= '0';
        
--        add_valid_out <= '0';
--    end if;
--end process add_sample;

------------------------------------------------------------------------------ 

---- subtract read fifo data from accumulator
--subtract_sample : process(subtract_data_ready)
--begin
--    if subtract_data_ready = '1' then
--        rd_en_s <= '1';
        
--        accumulator <= accumulator - signed(rd_data_s);
        
--        subtract_valid_out <= '1';
--    else
--        rd_en_s <= '0';
--         accumulator <= accumulator;
--        subtract_valid_out <= '0';
--    end if;
--end process subtract_sample;

------------------------------------------------------------------------------ 

----divide accumulator by fifo depth and store in new signal 
--divide_proc : process(divide_data_ready)
--begin
--    if divide_data_ready = '1' then
--        accumulator <= shift_right(accumulator, 5);
        
--        divide_valid_out <= '1';
--    else 
--        accumulator <= accumulator;
--        divide_valid_out <= '0';
--    end if;
--end process divide_proc;

------------------------------------------------------------------------------ 

---- square root 
-- root_sample : process(square_root_data_ready)
-- begin
--    if square_root_data_ready = '1' then
--        sqrt_result <= approx_sqrt(unsigned(abs(accumulator)));
        
--        square_root_valid_out <= '1';
        
--    else 
--         accumulator <= accumulator;
--        square_root_valid_out <= '0';
--    end if;
--end process root_sample;



math_proc : process(square_data_ready, add_data_ready, subtract_data_ready, divide_data_ready, square_root_data_ready)
begin
    if square_data_ready = '1' then
        left_square_data <= signed(left_data_in(AC_DATA_WIDTH-1 downto 0)) * signed(left_data_in(AC_DATA_WIDTH-1 downto 0));
        
        
        square_valid_out <= '1';
    else
   
        square_valid_out <= '0';
    end if;

    if add_data_ready = '1' then
        --accumulator <= left_square_data;
        
        wr_data_s <= std_logic_vector(left_square_data);
        wr_en_s <= '1';
   
        add_valid_out <= '1';
    else
       -- accumulator <= accumulator;
       wr_data_s <= (others => '0');
        wr_en_s <= '0';
 
        add_valid_out <= '0';
    end if;
    
    if subtract_data_ready = '1' then
       -- rd_en_s <= '1';
        
      --  accumulator <= accumulator - signed(rd_data_s);
        
        subtract_valid_out <= '1';
    else
       -- rd_en_s <= '0';
       -- accumulator <= accumulator;
        subtract_valid_out <= '0';
    end if;
    
    if divide_data_ready = '1' then
      --  accumulator <= shift_right(accumulator, 5);
        
        divide_valid_out <= '1';
    else 
     --   accumulator <= accumulator;
        divide_valid_out <= '0';
    end if;

    if square_root_data_ready = '1' then
        sqrt_result <= approx_sqrt(unsigned(abs(average)));
        
        square_root_valid_out <= '1';
        
    else 
        square_root_valid_out <= '0';
    end if;
  
 end process math_proc;


---------------------------------------------------------------------------- 

-- Next State Logic
next_state_logic : process(curr_state, aclk, s00_axis_tvalid)
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
                        next_state <= Read_Idle;
                    end if;
                when Read_Idle => 
                    next_state <= Remove_Oldest_Sample;
                    
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
    square_data_ready <= '0';
    add_data_ready <= '0';
    subtract_data_ready <= '0';
    divide_data_ready <= '0';
    square_root_data_ready <= '0';
   -- accumulator <= (others => '0');

    
        case curr_state is 
        
            when Idle =>
            
            when Square_Newest_Sample => 
                square_data_ready <= '1';
                
            when Add_Newest_Sample => 
                add_data_ready <= '1';
                accumulator <= accumulator + left_square_data;
                
           when Read_Idle =>
              if full_s = '1' then
                  rd_en_s <= '1';
                  subtract <= '1';
              end if;
              
            when Remove_Oldest_Sample =>
                subtract_data_ready <= '1';
                if subtract = '1' then
                    accumulator <= accumulator - signed(rd_data_s);
                end if;
                
            when Calculate_Average => 
                subtract <= '0';
                divide_data_ready <= '1';
                average <= shift_right(accumulator, 5);
                
            when Extract_Square_Root =>
                square_root_data_ready <= '1';
                
        end case;

end process fsm_output_logic;

---------------------------------------------------------------------------- 

-- State Update 
state_update: process(aclk)
begin
    if rising_edge(aclk) then
        curr_state <= next_state;
    end if;
end process state_update;

---------------------------------------------------------------------------- 
end Behavioral;
