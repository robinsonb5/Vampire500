library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity PinTest is
   port(
			iSYS_CLK				: in std_logic;		-- 50MHz clock
			reset_a			   : in std_logic;		-- System Reset
			reset_b			   : out std_logic;		-- System Reset
			halt_a				: in    std_logic;
			halt_b				: out    std_logic;
			clk_7Mhz          : in std_logic;      -- 7MHz clock from Amiga 600 motherboard 

			
--
-- MC68000 signals
--
        iTG68_IPLn         : in std_logic_vector(2 downto 0);
        iTG68_DTACKn       : in std_logic;
	     oTG68_ADDR     		: out std_logic_vector(23 downto 1);
        oTG68_ASn          : out std_logic;
		  iASn			      : in std_logic;
        oTG68_UDSn         : out std_logic:='1';
        oTG68_LDSn         : out std_logic:='1';
        oTG68_RW           : out std_logic:='1';		-- Read = '1', Write = '0'
        ioTG68_DATA 			: inout std_logic_vector(15 downto 0);
		  iBERRn				   : in    std_logic;
		  iVPA					: in	  std_logic;
		  oVMA					: out    std_logic;
		  FC						: out   std_logic_vector (2 downto 0):="111";
		  
		  oBRn					: out    std_logic:='1';
		  iBGn					: in    std_logic;
		  oBGACKn				: out    std_logic:='1';
		  E						: buffer   std_logic;
		  E_in               : in std_logic; 
		  VMA_in 				: in std_logic;
 

LED : out std_logic; 
--
-- ALVT U1 direction (Control signals)			
--
			U1_U2_OE 			: out std_logic:='1';
			U1_U2_DIR 			: out std_logic;
--

--
-- ALVT U2 direction  (Data bus)			
--
--			U2_1DIR_C			: out std_logic;
--			U2_1OE_C				: out std_logic;
			U2_2DIR_C			: out std_logic:='1';
			U2_2OE_C				: out std_logic:='1';
--

--
-- ALVT U3 direction	(Upper address bus)		
--
--			U3_1DIR_C			: out std_logic;
--			U3_1OE_C				: out std_logic;
			U3_2DIR_C			: out std_logic;
			U3_2OE_C				: out std_logic:='1';
--

--
-- ALVT U4 direction	(Lower address bus)		
--
			U4_1DIR_C			: out std_logic;
			U4_1OE_C				: out std_logic:='1';
			U4_2DIR_C			: out std_logic;
			U4_2OE_C				: out std_logic:='1'
--			
	
			  );
end PinTest;

ARCHITECTURE logic OF PinTest IS

-- Clock signals 
signal sysclk : std_logic; -- Master clock, about 128MHz.
signal signaltap_clk : std_logic;
signal counter : unsigned(26 downto 0);
signal onoff : std_logic;
BEGIN

-- PLL to generate 128Mhz from 50MHz sysclock.

mySysClock : entity work.SysClock
	port map(
		inclk0 => iSYS_CLK,
		pllena => '1',
		c0 => sysclk,
		c1 => signaltap_clk
	);

process(sysclk)
begin
	if rising_edge(sysclk) then
		counter<=counter+1;
	end if;
end process;

onoff<=counter(26);

E<=onoff;
oVMA <= onoff;
oTG68_ADDR <= (others=>onoff);
oTG68_ASn <= onoff;
oTG68_ASn <= onoff;
oTG68_UDSn <= onoff;
oTG68_LDSn <= onoff;
oTG68_RW <= onoff;
reset_b <= onoff;
halt_b <= onoff;
ioTG68_DATA <= (others=>onoff);
LED <= onoff;


U1_U2_DIR 			<= '1';    -- enable ALVC => ADDR
U1_U2_OE 			<= '0';

U2_2DIR_C			<= '1';		-- enable ALVC => VMA, RESET, HALT, etc
U2_2OE_C				<= '0';			

U3_2DIR_C			<= '1';		-- enable ALVC => AS,UDS,LDS,RW
U3_2OE_C				<= '0';			

U4_1DIR_C			<= '1'; 		
U4_1OE_C				<=	'0';		-- enable ALVC => DATA
U4_2DIR_C			<=	'1';	
U4_2OE_C				<=	'0';		


END;
