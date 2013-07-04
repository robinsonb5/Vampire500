library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.sdram_pkg.all;


entity SDRAMTest_Top is
   port(
			iSYS_CLK				: in std_logic;		-- 50MHz clock
			reset_a			   : in std_logic;		-- System Reset
			reset_b			   : out std_logic;	-- System Reset 
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
		U4_2OE_C				: out std_logic:='1';
--			
-- SDRAM Signals
		SDRAM_A : out std_logic_vector(12 downto 0);
		SDRAM_DQ : inout std_logic_vector(15 downto 0);
		SDRAM_WE		: out std_logic;	-- Write enable, active low
		SDRAM_RAS : out std_logic;	-- Row Address Strobe, active low
		SDRAM_CAS : out std_logic;	-- Column Address Strobe, active low
		SDRAM_CS : out std_logic;	-- Chip select
		SDRAM_DQMH : out std_logic;	-- Data mask, upper and lower byte
		SDRAM_DQML : out std_logic;	-- Data mask, upper and lower byte
		SDRAM_BA : buffer std_logic_vector(1 downto 0); -- Bank
		SDRAM_CLK : out std_logic;
		SDRAM_CKE : out std_logic
	
	);
end SDRAMTest_Top;

ARCHITECTURE logic OF SDRAMTest_Top IS

-- Fast RAM signals

signal sdram_ready : std_logic;
signal sdram_fromcpu : SDRAM_Port_FromCPU;
signal sdram_tocpu : SDRAM_Port_ToCPU;


-- Clock signals 
signal sysclk : std_logic; -- Master clock, about 128MHz.
signal amigaclk_r : std_logic; -- Amiga clock, synchronised to sysclk
signal amigaclk : std_logic; -- Amiga clock, double-synchronised to sysclk.
signal amigaclk_phase1 : std_logic_vector(4 downto 0); -- Count sysclks since the falling edge of 7Mhz
signal amigaclk_phase2 : std_logic_vector(4 downto 0); -- Count sysclks since the rising edge of 7Mhz
signal amiga_risingedge_read : std_logic;
signal amiga_fallingedge_read : std_logic;
signal amiga_risingedge_write : std_logic;
signal amiga_fallingedge_write : std_logic;
signal amiga_eitheredge_read : std_logic;
signal amiga_eitheredge_write : std_logic;

signal sampled_reset : std_logic;
signal sampled_reset_s : std_logic;

-- E Clock signals
signal eclk_shift : std_logic_vector(9 downto 0) := "1111000000";
signal eclk_fallingedge : std_logic;
signal VMA_int : std_logic;

--
-- FSM
--
signal TG68_RESETn : std_logic;  -- TG68 reset, active low


type mystates is
	(init,reset,state1,state2,main,bootrom,delay1,delay2,delay3,delay4,
	writeS0,writeS1,writeS2,writeS3,writeS4,writeS5,writeS6,writeS7,writeS8,
	readS0,readS1,readS2,readS3,readS4,readS5,readS6,readS7,fast_access,fast2,fast3);

signal mystate : mystates :=init;    -- Declare state machine variable with initial value of "init"

signal amiga_addr : std_logic_vector(23 downto 1); -- CPU's current address
signal reset_counter : unsigned(15 downto 0) := X"FFFF";



-- CPU signals

signal cpu_datain : std_logic_vector(15 downto 0);	-- Data provided by us to CPU
signal cpu_dataout : std_logic_vector(15 downto 0); -- Data received from the CPU
signal cpu_addr : std_logic_vector(31 downto 1); -- CPU's current address
signal cpu_as : std_logic; -- Address strobe
signal cpu_uds : std_logic; -- upper data strobe
signal cpu_lds : std_logic; -- lower data strobe
signal cpu_r_w : std_logic; -- read(high)/write(low)
signal cpustate : std_logic_vector(1 downto 0);
signal cpu_clkena : std_logic :='0';
signal tg68_ready : std_logic; -- High when the CPU is initialised and ready for use.
signal cpu_ipl_s : std_logic_vector(2 downto 0);
signal cpu_ipl : std_logic_vector(2 downto 0);

signal nullsig : std_logic_vector (31 downto 24);
signal nullsig0 : std_logic;

-- Fast RAM signals

signal sel_fast : std_logic;

BEGIN

-- PLL to generate 128Mhz from 50MHz sysclock.

mySysClock : entity work.SysClock
	port map(
		inclk0 => iSYS_CLK,
		pllena => '1',
		c0 => sysclk,
		c1 => SDRAM_CLK
	);


-- SDRAM - -Stub out the SDRAM for now.
--SDRAM_A <= (others => '1');
--SDRAM_DQ  <= (others => 'Z');
--SDRAM_WE <= '1';
--SDRAM_RAS <= '1';
--SDRAM_CAS <= '1';
--SDRAM_CS <= '0';
--SDRAM_DQMH <= '1';
--SDRAM_DQML <= '1';
--SDRAM_BA  <= (others => '1');
SDRAM_CKE <= '1';

	

	
-- Double-synchronise the Amiga clock signal.

process(sysclk,clk_7Mhz)
begin
	if rising_edge(sysclk) then
	
		-- Clean up the clock signal
		amigaclk<=amigaclk_r;   -- Usable Synchronised Amiga clock
		amigaclk_r<=clk_7Mhz;	-- First stage synchronised Amiga clock.
		
		if amigaclk='1' then
			amigaclk_phase1<="00000"; -- Reset counter while clock is high.
			amigaclk_phase2<=amigaclk_phase2+1;  -- Count sysclks since the rising edge
		else
			amigaclk_phase2<="00000"; -- Reset counter while clock is low
			amigaclk_phase1<=amigaclk_phase1+1;	-- Count sysclks since the falling edge
		end if;
		
		-- An enable signal we can use instead of rising_edge() or falling_edge()
		-- Note that the _read and _write designations here refer to whether signals
		-- are being changed by the FPGA or by the Amiga, and have nothing
		-- to do with whether these are read or write cycles.
		
		amiga_risingedge_read<='0';
		if amigaclk_phase1="00101" then -- phase 5 - might need to adjust this
			amiga_risingedge_read<='1';
		end if;	

		amiga_risingedge_write<='0';
		if amigaclk_phase1="00101" then   ----- 121Mhz 00101 risingedge 00110 fallingedge
			amiga_risingedge_write<='1';
		end if;

		amiga_fallingedge_read<='0';
		if amigaclk_phase2="00101" then -- phase 5 - might need to adjust this
			amiga_fallingedge_read<='1';
		end if;	
				
		amiga_fallingedge_write<='0';
		if amigaclk_phase2="00101" then -- phase 5 - might need to adjust this
			amiga_fallingedge_write<='1';
		end if;
	end if;
	amiga_eitheredge_read <= amiga_fallingedge_read or amiga_risingedge_read;
	amiga_eitheredge_write <= amiga_fallingedge_write or amiga_risingedge_write;
end process;


-- Synchronise the sampled_reset signal, and also the IPL signals
process(sysclk,sampled_reset_s)
begin
	if rising_edge(sysclk) then
		sampled_reset_s<=reset_a;
		sampled_reset<=sampled_reset_s;
		-- Interrupt signals - we sync once on the sysclk edge, then again on the 7MHz rising edge.
		-- This should ensure that the TG68 doesn't sample IPL during transition.
		cpu_ipl_s<=iTG68_IPLn;
		if amiga_risingedge_read='1' then
			cpu_ipl<=cpu_ipl_s;
		end if;
	end if;
end process;

	
-- Instantiate CPU and Boot ROM

myTG68 : entity work.TG68KdotC_Kernel
--myTG68 : entity work.DummyCPU
--myTG68 : entity work.ZPU_Bridge
	generic map
	(
		SR_Read =>2,
		VBR_Stackframe =>2,
		extAddr_Mode => 2,
		MUL_Mode => 2,
		DIV_Mode => 2,
		BitField => 2
	)
   port map
	(
		clk => sysclk,
      nReset => TG68_RESETn,  -- Contributes to reset, so have to use reset_in here.
      clkena_in => cpu_clkena,
      data_in => cpu_datain,
		IPL => cpu_ipl, -- Stub out with 1s for now.  Later we'll replace it with the IPL signals from the Amiga.
		IPL_autovector => '0',
		CPU => "11", -- 68000-mode for now.
		addr(31 downto 1) => cpu_addr,
		addr(0) => nullsig0,
		data_write => cpu_dataout,
		nWr => cpu_r_w,
		nUDS => cpu_uds,
		nLDS => cpu_lds,
		busstate => cpustate,
		nResetOut => tg68_ready,
		FC => open,
-- for debug		
		skipFetch => open,
		regin => open
	);


-- ECLK generation.
-- Every rising edge of the Amiga's clock we rotate a 10-bit register
-- 1 bit to the right.  The lowest bit of this register is output as the eclk signal.

process(sysclk)
begin
	eclk_fallingedge<=eclk_shift(9) and not eclk_shift(0);  -- 1 when shift="1111000000"
	if rising_edge(sysclk) then  -- Use sysclk rather than 7MHz clock so we have scope to adjust phase if need be.
		if amiga_risingedge_write='1' then
			eclk_shift<=eclk_shift(0)&eclk_shift(9 downto 1);	-- Rotate eclock register 1 bit right;
		end if;
	end if;
end process;

E<=eclk_shift(0);
oVMA <= VMA_int;

	
-- Simple boot ROM for testing.  Once this is tested and working we can remove it
-- and let the CPU boot from Kickstart.
--mybootrom : entity work.BootRom
--	port map (
--		clock => sysclk,
--		address => cpu_addr(8 downto 1),
--		q => romdata
--		);
	

oTG68_ADDR <= amiga_addr;
--oTG68_ADDR(0) <= null;
-- FSM who generates one reset on Amiga motherboards, and after that enables reset_fsm with fsm_ena(active high)

-- Address decoding...
sel_fast <= '1' when
  cpu_addr(31 downto 24)=X"01" -- 1000000 17ffff8
  else '0';

process(sysclk,reset_counter)
begin
  if rising_edge(sysclk) then

	cpu_clkena<='0';	-- The CPU will be paused by default.  The delay2 state will allow it to run for 1 cycle.
	
		 case mystate is	
			when init =>
			if amiga_risingedge_read='1' then
					U1_U2_DIR 			<= '1';    -- enable ALVC => ADDR
					U1_U2_OE 			<= '0';
					
					U2_2DIR_C			<= '1';		-- enable ALVC => VMA, RESET, BGACK, etc.
					U2_2OE_C				<= '0';			

					U3_2DIR_C			<= '1';		-- enable ALVC => AS,UDS,LDS,RW
					U3_2OE_C				<= '0';			

					U4_1DIR_C			<= '0'; 		
					U4_1OE_C				<=	'0';		-- enable ALVC => DATA
					U4_2DIR_C			<=	'0';	
					U4_2OE_C				<=	'0';		
					
							-- Here you should set direction of ADDR, AS, LDS, UDS and RW as output,
							-- and set DATA and DTACK as input

					oTG68_ASn   <='1';
					oTG68_RW    <='1';
					oTG68_UDSn  <='1';
					oTG68_LDSn  <='1';
				ioTG68_DATA <= (others=>'Z');	-- Make the data lines high-impedence, suitable for input
				VMA_int<='1';
--				amiga_addr  <= (others=>'Z');
			  reset_counter<=X"FFFF";
			  mystate<=reset;
			  -- Reset the Amiga....
			  reset_b <= '0';
			  halt_b <= '0';
				TG68_RESETn <= '0';
			 end if; 
			when reset =>
				if amiga_risingedge_read='1' then
				  if reset_counter=X"0000" then
					 mystate<=state1;
					 -- Release the reset signal...
					  reset_b <= '1';
					  halt_b <= '1'; 
				  end if;

				  reset_counter<=reset_counter-1;
				end if;

			when state1 =>
		
				-- This will be the first "real" state of state machine.
			  
			  
			  reset_b <= '1';
			  halt_b <= '1'; 
			
--				fsm_ena <= '1'; -- enables reset_fsm for bus arbitration sequence
			
					mystate<=state2;
		
			
			when state2 =>
			-- Check that the bus is now yours...
				TG68_RESETn <= '1';
				if amiga_risingedge_read='1' then			
					mystate<=main;	-- go the Main state.

						
--				else
--					mystate<=state2;
			   end if;


				-- **** This Main state directs the state machine depending upon the CPU address and write flag. ****
				
				when main =>
					null;
				
			when others =>
				null;

		end case;

	end if;
end process;


oBRn <='1';
oBGACKn <= '1';

mysdram : entity work.sdramtest
generic map
	(
		rows => 13,
		cols => 10
	)
port map
	(
	-- Physical connections to the SDRAM
		sdr_data => SDRAM_DQ,
		sdr_addr => SDRAM_A,
		sdr_we	=> SDRAM_WE,
		sdr_ras => SDRAM_RAS,
		sdr_cas => SDRAM_CAS,
		sdr_cs	=> SDRAM_CS,
		sdr_dqm(1) => SDRAM_DQMH,
		sdr_dqm(0) => SDRAM_DQML,
		sdr_ba=>SDRAM_BA,

	-- Housekeeping
		clk => sysclk,
		reset_n => TG68_RESETn,
		errorbits => amiga_addr(23 downto 8) -- Make sure they're not optimised away.
	);

	sdram_ready<='1';
	
END;
