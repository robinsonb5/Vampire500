library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mc68k_probe is
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
		  E						: out   std_logic;
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
end mc68k_probe;

ARCHITECTURE logic OF mc68k_probe IS




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



-- E Clock signals
signal e_counter : std_logic_vector(3 downto 0); 
signal VMA_int : std_logic;
signal E_int : std_logic;


signal SYNCn : std_logic;
signal SYNCn_low : std_logic;
signal signaltap_clk : std_logic;
--
-- FSM
--
signal TG68_RESETn : std_logic;  -- TG68 reset, active low


type mystates is
	(init,reset,state1,state2,main,bootrom,delay1,delay2,delay3,
	writeS0,writeS1,writeS2,writeS3,writeS4,writeS5,writeS6,writeS7,writeS8,
	readS0,readS1,readS2,readS3,readS4,readS5,readS6,readS7,read_wait,read_wait2);

signal mystate : mystates :=init;    -- Declare state machine variable with initial value of "init"

signal amiga_addr : std_logic_vector(23 downto 1); -- CPU's current address
signal reset_counter : unsigned(15 downto 0) := X"FFFF";








-- CPU signals

signal cpu_datain : std_logic_vector(15 downto 0);	-- Data provided by us to CPU
signal cpu_dataout : std_logic_vector(15 downto 0); -- Data received from the CPU
signal cpu_addr : std_logic_vector(23 downto 1); -- CPU's current address
signal cpu_as : std_logic; -- Address strobe
signal cpu_uds : std_logic; -- upper data strobe
signal cpu_lds : std_logic; -- lower data strobe
signal cpu_r_w : std_logic; -- read(high)/write(low)
signal cpustate : std_logic_vector(1 downto 0);
signal cpu_clkena : std_logic :='0';
signal tg68_ready : std_logic; -- High when the CPU is initialised and ready for use.


signal nullsig : std_logic_vector (31 downto 24);
signal nullsig0 : std_logic;

BEGIN

-- PLL to generate 128Mhz from 50MHz sysclock.

mySysClock : entity work.SysClock
	port map(
		inclk0 => iSYS_CLK,
		pllena => '1',
		c0 => sysclk,
		c1 => signaltap_clk
	);

	
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
		amiga_risingedge_read<='0';
		if amigaclk_phase1="00011" then -- phase 5 - might need to adjust this
			amiga_risingedge_read<='1';
		end if;	

		amiga_risingedge_write<='0';
		if amigaclk_phase1="00011" then   ----- 121Mhz 00101 risingedge 00110 fallingedge
			amiga_risingedge_write<='1';
		end if;

		amiga_fallingedge_read<='0';
		if amigaclk_phase2="00011" then -- phase 5 - might need to adjust this
			amiga_fallingedge_read<='1';
		end if;	
				
		amiga_fallingedge_write<='0';
		if amigaclk_phase2="00011" then -- phase 5 - might need to adjust this
			amiga_fallingedge_write<='1';
		end if;
	end if;
end process;

	
-- Instantiate CPU and Boot ROM

myTG68 : entity work.TG68KdotC_Kernel
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
		IPL => iTG68_IPLn, -- Stub out with 1s for now.  Later we'll replace it with the IPL signals from the Amiga.
		IPL_autovector => '0',
		CPU => "11", -- 68000-mode for now.
		addr(31 downto 24) => nullsig,
		addr(23 downto 1) => cpu_addr,
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

process(reset_a,clk_7Mhz) is
begin
if reset_a = '0' then
e_counter <= "0000";
elsif e_counter = "1010" then
e_counter <= "0000";
elsif rising_edge(clk_7Mhz) then
e_counter <= e_counter + 1;
end if;
end process; 

E <= '1' when e_counter = "0110" or e_counter = "0111" or e_counter = "1000" or e_counter = "1001" else '0';
--SYNCn <= '0' when (VMA_int ='0' and (e_counter = "1000" or e_counter = "1001")) else '1';
--SR FlipFlop
process(clk_7Mhz,reset_a)
begin
if reset_a = '0' then
VMA_int <= '1';
elsif rising_edge(clk_7Mhz) then
if (e_counter = "0010" and iVPA = '0') then
VMA_int <= '0';
elsif iVPA = '1' then
VMA_int <= '1';
end if;
end if;
end process;

--Generate SYNC to end bus cycle

process(clk_7Mhz,reset_a)
begin
if reset_a = '0' then
SYNCn <= '1';
elsif rising_edge(clk_7Mhz) then
if (VMA_int ='0' and (e_counter = "1000" or e_counter = "1001")) then
SYNCn <= '0';
else 
SYNCn <= '1';
end if;
end if;
end process;


--Generate SYNC to end bus cycle





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

process(sysclk,reset_counter)
begin
  if rising_edge(sysclk) then

	cpu_clkena<='0';	-- The CPU will be paused by default.  The delay2 state will allow it to run for 1 cycle.
	
		 case mystate is	
			when init =>
			if amiga_risingedge_read='1' then
				ioTG68_DATA <= (others=>'Z');	-- Make the data lines high-impedence, suitable for input
--				amiga_addr  <= (others=>'Z');
			  reset_counter<=X"FFFF";
			  mystate<=reset;
			  -- Reset the Amiga....
			  reset_b <= '0';
			  halt_b <= '0'; 
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

					U1_U2_DIR 			<= '1';    -- enable ALVC => ADDR
					U1_U2_OE 			<= '0';
					
		
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
						
--				else
--					mystate<=state2;
			   end if;


				-- **** This Main state directs the state machine depending upon the CPU address and write flag. ****
				
				when main =>
					if cpustate="01" then -- CPU state 01 (decode) doesn't involve any external access
						 -- We run CPU one more cycle
						mystate<=delay1;	-- so we just skip straight to the delay state.
												-- (at 7Mhz no delays are strictly necessary,
												-- but they certainly will be once we ramp up the speed.)
					else
					
						if cpu_r_w='0' then	-- Write cycle.
--									if amiga_risingedge_read='1' then
									
									mystate <= writeS0;
--									end if;
								elsif	cpu_r_w='1' then -- Read cycle
									mystate <= readS0;
						end if;
								
					end if;


			when delay1 =>
				mystate<=delay2;
				
			when delay2 =>
				cpu_clkena<='1';			
				mystate<=delay3;
				
				
			when delay3 =>
         mystate<=main;
		
		
		
	
				
	
			-- **** WRITE CYCLE ****
			when writeS0 =>
				if amiga_risingedge_write='1' then -- Rising edge of S0
					oTG68_RW   <='1'; -- Drive RW high for the start of the sequence
											-- (Should be high anyway from previous cycle, so we don't bother to wait.)
					mystate<=writeS1;
					
				end if;

			when writeS1 =>
				if amiga_fallingedge_write='1' then	-- Entering S1 the CPU drives the Address lines.
					amiga_addr <= cpu_addr(23 downto 1);
					mystate<=writeS2;
				end if;
				
			when writeS2 =>	
				if amiga_risingedge_write='1' then -- On the rising edge of S2...
					oTG68_ASn  <='0'; -- Now pull /AS low to indicate that a valid address is on the bus
					oTG68_RW   <='0'; -- Let Amiga know this is a write cycle.
					mystate<=writeS3;
				end if;
				
			when writeS3 =>
				if amiga_fallingedge_write='1' then -- Entering S3...		
					U4_1DIR_C <= '1';
					U4_1OE_C  <= '0';            -- ALVC devices as output
					U4_2DIR_C <= '1';         
					U4_2OE_C  <= '0';			
					ioTG68_DATA<=cpu_dataout;     -- DATA to Amiga bus			
					mystate<=writeS4;
				end if;

			when writeS4 =>
					
				if amiga_risingedge_write='1' then -- Entering S4...	
					oTG68_UDSn  <=cpu_uds;	-- Write UDS/LDS on rising edge of S4
					oTG68_LDSn  <=cpu_lds;
							
					if iTG68_DTACKn ='0' or SYNCn = '0' then	-- Wait for DTACK or VPA
						mystate<=writeS5;	-- Skip State 5 since nothing happens there.
					
					end if;
					
					
				end if;
				
				
				
				
			when writeS5 => -- Nothing happens during S5			
		        if amiga_fallingedge_write='1' then
				  mystate<=writeS6;
				  end if;
				  			
			when writeS6 => -- Nothing happens during S3
				if amiga_risingedge_write='1' then 	
--					cpu_clkena<='1'; -- We've finished with the CPU data now, so let the CPU run for 1 cycle
					mystate<=writeS7;
				end if;
				
					
			when writeS7 =>
--				cpu_clkena<='1';			
				if amiga_fallingedge_write='1' then -- Entering S7				
					oTG68_ASn  <= '1';
					oTG68_UDSn <= '1';
					oTG68_LDSn <= '1';
					mystate<=writeS8;
				end if;

			when writeS8 =>	-- This is just cleaning up in preparation for the next cycle.
									-- The rising edge here is the rising edge of the next cycle's S0 state.
				if amiga_risingedge_write='1' then

					oTG68_RW <='1';
					U4_1DIR_C <= '0';
					U4_1OE_C  <= '0';            -- ALVC devices as input
					U4_2DIR_C <= '0';
					U4_2OE_C  <= '0';	
					ioTG68_DATA <= (others=>'Z');
					amiga_addr  <= (others=>'Z');
--					if cpustate="01" then
					
						mystate<=delay2;						
--					else
--						if cpu_r_w='0' then					
--							mystate<=writeS0;
--						else													
--							mystate <= readS0;
--						end if;
--					end if;
				end if;		
					
		
				
			-- **** READ CYCLE ****

			when readS0 =>	
				if amiga_risingedge_read='1' then
--				amiga_addr  <= (others=>'Z');
				oTG68_RW   <='1'; -- Let Amiga know this is a read cycle.
				mystate<=readS1;
				end if;
				
			when readS1 =>
				if amiga_fallingedge_read='1' then	-- Entering S1...
					amiga_addr <= cpu_addr(23 downto 1);
					mystate<=readS2;
				end if;
				
			when readS2 =>									
				if amiga_risingedge_read='1' then -- Rising edge of S2
					oTG68_ASn  	<='0'; -- Now pull /AS low to indicate that a valid address is on the bus			
					-- The DATA lines are inputs by default, so we don't have to worry about the direction lines								
--					oTG68_UDSn  <='0';
--					oTG68_LDSn  <='0';

					oTG68_UDSn  <=cpu_uds;	
					oTG68_LDSn  <=cpu_lds;
								
						mystate<=readS3;	
				end if;	
				
			when readS3 =>
				if amiga_fallingedge_read='1' then	-- Entering S3...
					mystate<=readS4;
				end if;	
				
				when readS4 =>
					if amiga_risingedge_read='1' then
					
						if iTG68_DTACKn ='0' or SYNCn = '0' then
						mystate<=readS6;
--						elsif iVPA = '0' then 
--						mystate<=read_wait;
						end if;
					end if;
				
			when readS5 =>
					if amiga_fallingedge_read='1' then	-- Entering S6...
														
							mystate<=readS6;
							
					end if;
				
			when readS6 =>
				if amiga_fallingedge_read='1' then
					U4_1DIR_C <= '0';	-- Set ALVCs to input, and give them time to turn around.
					U4_1OE_C  <= '0';	-- (They should be input already, but it doesn't hurt to be sure.)
					U4_2DIR_C <= '0';
					U4_2OE_C  <= '0';
					cpu_datain<=ioTG68_DATA;
					mystate <= readS7;
				end if;
				
				
				
			when read_wait =>					
					if SYNCn = '0' then 
					mystate <= readS6;
					end if;
					
					
			
				
			when readS7 =>	
--				cpu_clkena<='1';	-- Allow the CPU to run for 1 clock.			
				if amiga_fallingedge_read='1' then -- Rising edge of next S0
					oTG68_ASn   <='1'; -- Release /AS
					oTG68_UDSn  <='1';
					oTG68_LDSn  <='1'; -- Release /UDS and /LDS
					
--					end if;
--				if amiga_risingedge_read='1' then 	
	
					ioTG68_DATA <= (others=>'Z');
					amiga_addr  <= (others=>'Z');
					mystate <= delay1;
--					if cpustate="01" then
												
--					else
--						if cpu_r_w='0' then					
--						mystate<=writeS0;
--					else													
--						mystate <= readS0;
--						end if;
--					end if;
				end if;		
				
				
			when others =>
				null;

		end case;
	end if;
end process;

--LED <= SYNCn;

--Reset_FSM_inst: reset_fsm
--   port map( 
--    iCLK_7MHZ     => clk_7Mhz,      -- 7MHz clock
--    iRESETn       => reset_a,       -- Active low reset from Amiga 600 motherboards
--	 fsm_ena => fsm_ena,
--
-- MC68k signals
--
--    iASn          => iASn,         -- MC68k address strobe, active low
--    iDTACKn       => iTG68_DTACKn,       -- MC68k DTACKn
--	 ioBRn			=> oBRn,         -- Bus Request output to MC68k
--	 iBGn          => iBGn,          -- Bus Grant input from MC68k
--	 oBGACKn			=> oBGACKn       -- Bus Grant Acknowledge to the MC68k
	 

--
-- TG68 signals
--
 --   oTG68_RESETn  => TG68_RESETn  -- TG68 reset, active low
--		);
		

--
-- ALVT U1 direction		Cocntrol bus	
--
--			U1_U2_OE 			<= '0';
--			U1_U2_DIR 			<= '0';
		
--			U1_1DIR_C			<= '0';  -- '0' = B to A, = input to FPGA
--			U1_1OE_C				<= '0'; -- '0' = always enable outputs
--			U1_2DIR_C			<= '0';
--			U1_2OE_C				<= '0';
 

--
-- ALVT U2 direction		Data bus	
--

--			U2_1DIR_C			<= '0'; -- '0' = RD, '1' = WR
--			U2_1OE_C				<= '0';
--			U2_2DIR_C			<= '1';
--			U2_2OE_C				<= '0';
 

--
-- ALVT U3 direction	Upper address bus		
--

--			U3_1DIR_C			<= '0';
--			U3_1OE_C				<= '0';
--			U3_2DIR_C			<= '0';
--			U3_2OE_C				<= '0';
 

--
-- ALVT U4 direction	Lower address bus		
--

--			U4_1DIR_C			<= '0';
--			U4_1OE_C				<= '0';
--   		U4_2DIR_C			<= '0';
--  		U4_2OE_C				<= '0';
-- 

END;
