library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.sdram_pkg.all;


entity Vampire500_Top is
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
--		SDRAM_A : out std_logic_vector(12 downto 0);
--		SDRAM_DQ : inout std_logic_vector(15 downto 0);
--		SDRAM_WE		: out std_logic;	-- Write enable, active low
--		SDRAM_RAS : out std_logic;	-- Row Address Strobe, active low
--		SDRAM_CAS : out std_logic;	-- Column Address Strobe, active low
--		SDRAM_CS : out std_logic;	-- Chip select
--		SDRAM_DQMH : out std_logic;	-- Data mask, upper and lower byte
--		SDRAM_DQML : out std_logic;	-- Data mask, upper and lower byte
--		SDRAM_BA : out std_logic_vector(1 downto 0); -- Bank
--		SDRAM_CLK : out std_logic;
--		SDRAM_CKE : out std_logic;
		sdram_pins_io : inout SDRAM_Pins_io;
		sdram_pins_o : out SDRAM_Pins_o;

		SD_CLK : out std_logic;
		SD_CS : out std_logic;
		SD_MOSI : out std_logic;
		SD_MISO : in std_logic
	);
end Vampire500_Top;

ARCHITECTURE logic OF Vampire500_Top IS

-- Fast RAM signals

signal sdram_clk : std_logic;
signal sdram_ready : std_logic;
signal fastram_fromcpu : SDRAM_Port_FromCPU;
signal fastram_tocpu : SDRAM_Port_ToCPU;


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
signal VPA_s : std_logic;
signal VPA : std_logic;
signal DTACK_s : std_logic;
signal DTACK : std_logic;

--
-- FSM
--
signal TG68_RESETn : std_logic;  -- TG68 reset, active low


type mystates is
	(init,reset,state1,state2,main,bootrom,delay1,delay2,delay3,delay4,delay5,
	writeS0,writeS1,writeS2,writeS3,writeS4,writeS5,writeS6,writeS7,writeS8,
	readS0,readS1,readS2,readS3,readS4,readS5,readS6,readS7,fast_access,fast2,fast3,
	vampire1, vampire2,bootrom1, bootrom2);

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

signal sdram_addr : std_logic_vector(31 downto 1); -- CPU's current address
signal ziii_base : std_logic_vector(7 downto 0):=X"10";
signal ziii_base2 : std_logic_vector(7 downto 0):=X"12";
signal sel_zii_fast : std_logic;
signal sel_ziii_fast : std_logic;
signal sel_ziii_fast2 : std_logic;
signal sel_chipram : std_logic;
signal sel_kickstart_shadow_r : std_logic;
signal sel_kickstart_shadow_w : std_logic;
signal sel_24bit : std_logic;
signal sel_autoconfig : std_logic;
signal sel_autoconfig2 : std_logic;
signal sel_vampire : std_logic;
signal sel_bootrom : std_logic;

-- Autoconfig signals

signal autoconfig_data : std_logic_vector(3 downto 0); -- 24-bit (Zorro II) autoconfig data;
signal autoconfig_data2 : std_logic_vector(3 downto 0); -- 32-bit (Zorro III) autoconfig data;
signal autoconfig_out : std_logic_vector(1 downto 0); -- Select between 24- and 32-bit autoconfig.

signal vampire_req : std_logic;
signal vampire_ack : std_logic;
signal vampire_data : std_logic_vector(15 downto 0);
signal bootrom_data : std_logic_vector(15 downto 0);
signal bootrom_data_latched : std_logic_vector(15 downto 0);
signal rom_overlay : std_logic :='0'; -- Vampire ROM overlay, as opposed to Kickstart ROM overlay.

signal kickstart_shadow_ena : std_logic;
signal kickstart_shadow_we : std_logic;
signal causereset : std_logic;

type cpudatasources is (src_amiga,src_sdram,src_autoconfig,src_peripheral,
	src_vampire,src_bootrom,src_busnoise);
signal cpudatasource : cpudatasources := src_amiga;

BEGIN


-- PLL to generate sysclk from 50MHz input clock.

mySysClock : entity work.SysClock
	port map(
		inclk0 => iSYS_CLK,
		pllena => '1',
		c0 => sysclk,
		c1 => sdram_clk
	);
	

	
-- Double-synchronise the Amiga clock signal
-- and VPA signal.

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
		if amigaclk_phase1="00100" then -- phase 5 - might need to adjust this
			amiga_risingedge_read<='1';
		end if;	

		amiga_risingedge_write<='0';
		if amigaclk_phase1="00100" then   ----- 121Mhz 00101 risingedge 00110 fallingedge
			amiga_risingedge_write<='1';
		end if;

		amiga_fallingedge_read<='0';
		if amigaclk_phase2="00100" then -- phase 5 - might need to adjust this
			amiga_fallingedge_read<='1';
		end if;	
				
		amiga_fallingedge_write<='0';
		if amigaclk_phase2="00100" then -- phase 5 - might need to adjust this
			amiga_fallingedge_write<='1';
		end if;
	end if;
	amiga_eitheredge_read <= amiga_fallingedge_read or amiga_risingedge_read;
	amiga_eitheredge_write <= amiga_fallingedge_write or amiga_risingedge_write;

end process;


-- Double-sync the VPA and DTACK signals
process(sysclk)
begin
	if rising_edge(sysclk) then
		VPA_s<=iVPA;
		VPA<=VPA_s;
		DTACK_s<=iTG68_DTACKn;
		DTACK<=DTACK_s;
	end if;
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

	
-- Simple boot ROM for testing.
mybootrom : entity work.BootRom
	port map (
		clock => sysclk,
		address => cpu_addr(12 downto 1),
		q => bootrom_data
	);

-- Custom hardware registers provided by the Vampire (for SPI, etc.)

vampireregs : entity work.Vampire_Registers
port map (
	clk => sysclk,
	reset => TG68_RESETn,
	addr => cpu_addr(3 downto 1)&'0',
	fromcpu => cpu_dataout,
	tocpu => vampire_data,
	rw => cpu_r_w,
	req => vampire_req,
	ack => vampire_ack,
	-- SPI signals
	sd_cs => SD_CS,
	sd_clk => SD_CLK,
	sd_mosi => SD_MOSI,
	sd_miso => SD_MISO,
	kickstart_we => kickstart_shadow_we,
	kickstart_ena => kickstart_shadow_ena,
	causereset => causereset
--	rom_overlay => rom_overlay
);

oTG68_ADDR <= amiga_addr;
--oTG68_ADDR(0) <= null;
-- FSM who generates one reset on Amiga motherboards, and after that enables reset_fsm with fsm_ena(active high)


-- Address decoding...

sel_24bit <= '1' when
	cpu_addr(31 downto 24)=X"00" else '0'; -- 0x000000 to 0xffffff

-- The first set of autoconfig data (Zorro II RAM)
sel_autoconfig <= '1' when
	sel_24bit='1' and autoconfig_out="01" and cpu_addr(23 downto 16)=X"E8" else '0'; -- Autoconfig space

-- The second set of autoconfig data (Zorro III RAM)
sel_autoconfig2 <= '1' when
	sel_24bit='1' and autoconfig_out="10" and cpu_addr(23 downto 16)=X"E8" else '0'; -- Autoconfig space

-- The chipram range.  This signal is only used to subtract chip RAM from the Z-II RAM range.
sel_chipram <= '1' when
	sel_24bit='1' and cpu_addr(23 downto 21)="000" else '0'; -- Chip RAM space, 0000000 to 1fffff

-- Zorro II Fast RAM
sel_zii_fast <= '1' when
	sel_24bit='1' and sel_chipram='0' and
		(cpu_addr(23)='0'	or cpu_addr(23 downto 21)="100")	-- Zorro II Fast RAM.
			else '0';

-- Zorro III Fast RAM
sel_ziii_fast <= '1' when
	cpu_addr(31 downto 25)=ziii_base(7 downto 1)
		else '0';
--  sel_24bit<='0' and cpu_addr(31)='0' -- 1000000 upwards, aliased to fill the address space.
--  else '0';

-- Zorro III Fast RAM
sel_ziii_fast2 <= '1' when
	cpu_addr(31 downto 25)=ziii_base2(7 downto 1)
		else '0';

-- Kickstart shadow - for reading
sel_kickstart_shadow_r <= '1' when
	sel_24bit='1' and cpu_addr(23 downto 20)=X"F" and kickstart_shadow_ena='1'
		else '0';

-- Kickstart shadow - for writing
sel_kickstart_shadow_w <= '1' when
	sel_24bit='1' and cpu_addr(23 downto 20)=X"F" and kickstart_shadow_we='1'
		else '0';

-- Custom Vampire 500 registers
sel_vampire <= '1' when
	sel_24bit='1' and cpu_addr(23 downto 16)=X"EF" else '0';

-- Vampire Boot ROM
sel_bootrom <= '1' when
	sel_24bit='1' and cpu_addr(23 downto 16)=X"EE" else '0';


-- Map Zorro II fast RAM to memory starting 48 meg in.
-- This leaves the low 48 meg for zorro III fast RAM,
-- and the last 8 meg for Kickstart mapping, Ranger RAM,
-- hard disk buffers or anything else we decide to do.
--sdram_addr(25)<= sel_zii_fast;
--sdram_addr(24)<= sel_zii_fast or cpu_addr(24);
--sdram_addr(23 downto 1)<=cpu_addr(23 downto 1);
--sdram_addr(25 downto 1)<=cpu_addr(25 downto 1);

-- SDRAM mapping:
--		Zorro II card from 0x00200000 - 0x00a00000 -> 0x00200000 - 0x00a00000, direct mapping
--   Zorro III card from 0x40000000 - 0x42000000 -> 0x02000000 - 0x04000000
--   Zorro III card from 0x42000000 - 0x43000000 -> 0x01000000 - 0x02000000
--    Spare regions from 0x00000000 - 0x00200000  & 0x00a00000 - 0x01000000
--   We can direct map the Kickstart ROM!
--   Just need to take care of interrupt acknowledge cycles?  Or ignore them and let the
--   real Kickstart ROM take care of them?

--   Bits 31 downto 26 are always 0.
--   Bit 25 <= sel_ziii
--   Bit 24 <= cpu_addr(24) or sel_ziii2

sdram_addr(25)<= sel_ziii_fast;
sdram_addr(24)<= sel_ziii_fast2 or cpu_addr(24);
sdram_addr(23 downto 1)<=cpu_addr(23 downto 1);

--process(sysclk)
--begin 
--	-- Zorro II RAM (Up to 8 meg at 0x200000)
--	autoconfig_data <= "1111";
--	CASE cpu_addr(6 downto 1) IS
--		WHEN "000000" => autoconfig_data <= "1110";		--Zorro-II card, add mem, no ROM
--		WHEN "000001" => autoconfig_data <= "0000";		--8MB
--		WHEN "001000" => autoconfig_data <= "1110";		-- 5016=Majsta
--		WHEN "001001" => autoconfig_data <= "1100";		
--		WHEN "001010" => autoconfig_data <= "0110";		
--		WHEN "001011" => autoconfig_data <= "0111";		
--		WHEN "010011" => autoconfig_data <= "1110";		--serial=1
--		WHEN OTHERS => null;
--	END CASE;
--end process;

process(cpu_addr(6 downto 1))
begin 
	-- Zorro III RAM (Up to 8 meg at 0x200000)
	autoconfig_data <= "1111";
	CASE cpu_addr(6 downto 1) IS
		WHEN "000000" => autoconfig_data <= "1010";		--Zorro-III card, add mem, no ROM
		WHEN "000001" => autoconfig_data <= "0001";		--32 meg (with extension bit)
		WHEN "000100" => autoconfig_data <= "0000";		-- Extended 
		WHEN "001000" => autoconfig_data <= "1110";		-- 5016=Majsta
		WHEN "001001" => autoconfig_data <= "1100";
		WHEN "001010" => autoconfig_data <= "0110";
		WHEN "001011" => autoconfig_data <= "0111";
		WHEN "010011" => autoconfig_data <= "1110";		--serial=1
		WHEN OTHERS => null;
	END CASE;
end process;


process(sysclk)
begin
	if sampled_reset='0' then
		ziii_base <= X"10";
		ziii_base <= X"12";
		autoconfig_out<="01";
	elsif rising_edge(sysclk) then
		if sel_autoconfig='1' and cpu_addr(6 downto 1)="100010" then 	-- Base address register, 0x44 - 
															-- assign base address to ZIII RAM.
			if cpu_r_w='0' then -- Write cycle
--				case autoconfig_out is
--					when "01" => -- Zorro II -- just skip over to Zorro III board 1
						ziii_base<=cpu_dataout(15 downto 8); -- Zorro III boards are configured by writing to 44; write to 48 happens first.
						autoconfig_out<="00";
--					when others =>
--						null;
--					autoconfig_out<="00";	-- Move on to the next autoconfig 
--				end case;
			end if;
		end if;
	end if;
end process;

		
-- Multiplexer for CPU Data in.
cpu_datain <= ioTG68_Data when cpudatasource=src_amiga
	else fastram_tocpu.data when cpudatasource=src_sdram
--	else autoconfig_data & fastram_tocpu.data(11 downto 0) when cpudatasource=src_autoconfig and autoconfig_out="01"
--	else autoconfig_data2 & fastram_tocpu.data(11 downto 0) when cpudatasource=src_autoconfig and autoconfig_out="10"
	else vampire_data when cpudatasource=src_vampire
	else bootrom_data_latched when cpudatasource=src_bootrom
		---src_peripheral, etc.
	else
		(others => '1'); -- "bus noise"

		
  
process(sysclk,reset_counter)
begin

	-- Respond to reset signal
	if sampled_reset='0' then
		mystate <= init;
	elsif rising_edge(sysclk) then

		cpu_clkena<='0';	-- The CPU will be paused by default.  The delay2 state will allow it to run for 1 cycle.
	
		 case mystate is	
			when init =>
			if amiga_risingedge_read='1' then
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
--				autoconfig_out<="01";
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
						if sel_zii_fast='1' or sel_ziii_fast='1' then
							cpudatasource<=src_sdram;
							fastram_fromcpu.req<='1';
							mystate<=fast_access;
						elsif sel_vampire='1' then
							cpudatasource<=src_vampire;
							vampire_req<='1';
							mystate<=vampire1;
						elsif sel_autoconfig='1' then
							cpudatasource<=src_autoconfig;
--							if cpu_r_w='0' and cpu_addr(6 downto 1)="100100" then -- Register 0x48 - config
--								autoconfig_out<="00";
--							end if;
							mystate<=delay1;
						elsif sel_autoconfig2='1' then
							cpudatasource<=src_autoconfig;
--							if cpu_r_w='0' and cpu_addr(6 downto 1)="100100" then -- Register 0x48 - config
--								autoconfig_out<="00";
--							end if;
							mystate<=delay1;
						elsif sel_bootrom='1' or (rom_overlay='1' and sel_chipram='1') then
							cpudatasource<=src_bootrom;
							bootrom_data_latched<=bootrom_data;
							mystate<=bootrom;
						elsif sel_24bit='1' then			
							cpudatasource<=src_amiga;
							if cpu_r_w='0' then	-- Write cycle.
								mystate <= writeS0;
							else -- Read cycle
								mystate <= readS0;
							end if;
						else
							cpudatasource<=src_busnoise;
							mystate<=delay1;
						end if;
					end if;

					if causereset='1' then
						vampire_req<='0';
						mystate<=init;
					end if;

			when vampire1 =>
				if vampire_ack='1' then
					mystate<=delay1;
				end if;

			when bootrom =>
				bootrom_data_latched<=bootrom_data;
				mystate<=bootrom2;

			when bootrom2 =>
				mystate<=delay1;

			when fast_access =>
--				cpu_datain<=fastram_tocpu.data;	-- copy data from SDRAM to CPU. (Unnecessary but harmless for write cycles.)
				if fastram_tocpu.ack='0' then
					fastram_fromcpu.req<='0'; -- Cancel the request, since it's been acknowledged.
					if cpu_r_w='0' then -- If we're writing we can let the CPU continue immediately...
						cpu_clkena<='1';
						mystate<=delay3;
					else
						mystate<=delay1;	-- If reading we let the data settle...
					end if;
				end if;
				
--			when fast2 =>
--				mystate<=delay2;
--				mystate<=fast3;

--			when fast3 =>
--				cpu_clkena<='1';
--				mystate<=delay3;
				

--			when fast3 => -- We give the data yet one more clock to settle.
--				mystate<=delay1;
		
			when delay1 =>
				mystate<=delay2;
				
			when delay2 =>
				cpu_clkena<='1';			
				mystate<=delay3;
				
			when delay3 =>
				mystate<=delay4;
				
			when delay4 =>
				mystate<=main;
--				mystate<=delay5;

			when delay5 =>
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
					U1_U2_OE 			<= '0';  -- enable address bus
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
				end if;
				if amiga_eitheredge_read='1' then -- Allow a little time for incoming signals to come through the ALVC.
					-- 6800-style cycle?
					if VPA='0' and E='0' then -- Don't actually need an edge, eclk simply needs to be low.
						VMA_int<='0';
						mystate<=writeS5;
						cpu_clkena<='1';			
					elsif DTACK ='0' then	-- Wait for DTACK or VPA
						cpu_clkena<='1';
						mystate<=writeS5;
					end if;					
				end if;
				
				
			when writeS5 => -- Nothing happens during S5			
				if amiga_eitheredge_write='1' then
					mystate<=writeS6;
				end if;
				  			
			when writeS6 => -- Nothing happens during S3
				if VPA='0' then
					if eclk_fallingedge='1' then
						mystate<=writeS7;
					end if;
				else -- if amiga_risingedge_write='1' then 	
--					cpu_clkena<='1'; -- We've finished with the CPU data now, so let the CPU run for 1 cycle
					mystate<=writeS7;
				end if;
		
			when writeS7 =>
--				if amiga_fallingedge_write='1' then -- Entering S7				
					oTG68_ASn  <= '1';
					oTG68_UDSn <= '1';
					oTG68_LDSn <= '1';
					ioTG68_DATA <= (others=>'Z');
					U4_1DIR_C <= '0';
					U4_1OE_C  <= '0';            -- ALVC devices as input
					U4_2DIR_C <= '0';
					U4_2OE_C  <= '0';	
					oTG68_RW <='1';
--					amiga_addr  <= (others=>'0');
					U1_U2_OE 			<= '1';  -- Render address bus high-z
					VMA_int<='1';
					mystate<=main;
--				end if;

			when writeS8 =>	-- This is just cleaning up in preparation for the next cycle.
									-- The rising edge here is the rising edge of the next cycle's S0 state.
				if amiga_risingedge_write='1' then

					oTG68_RW <='1';
--					amiga_addr  <= (others=>'0');
					U1_U2_OE 			<= '1';  -- Render address bus high-z
					VMA_int<='1';
--					if cpustate="01" then
					
						mystate<=main;						
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
				if amiga_risingedge_write='1' then
--				amiga_addr  <= (others=>'Z');
				oTG68_RW   <='1'; -- Let Amiga know this is a read cycle.
				mystate<=readS1;
				end if;
				
			when readS1 =>
--				if amiga_fallingedge_write='1' then	-- Entering S1...
					amiga_addr <= cpu_addr(23 downto 1);
					U1_U2_OE 			<= '0';  -- enable address bus
					mystate<=readS2;
--				end if;
				
			when readS2 =>
--				if amiga_eitheredge_write='1' then -- Rising edge of S2
					oTG68_ASn  	<='0'; -- Now pull /AS low to indicate that a valid address is on the bus			
					-- The DATA lines are inputs by default, so we don't have to worry about the direction lines								

					oTG68_UDSn  <=cpu_uds;	
					oTG68_LDSn  <=cpu_lds;
								
					mystate<=readS3;	
--				end if;	
				
			when readS3 =>
				if amiga_eitheredge_write='1' then	-- Entering S3...
					mystate<=readS4;
				end if;	
				
			when readS4 =>
				if amiga_risingedge_read='1' then -- "read" to allow time for ALVCs to do their thing.

					if VPA='0' and E='0' then -- We're looking at a 6800 cycle, and are synchronised to the E clock
						VMA_int<='0'; -- Indicate to 6800 device that the cycle is ready to proceed.
						mystate<=readS6;
					elsif DTACK ='0' then -- Normal cycle.
						mystate<=readS6;
					end if;
				end if;
				
			when readS5 =>
					if amiga_fallingedge_read='1' then	-- Entering S6...										
							mystate<=readS6;		
					end if;
				
			when readS6 =>
--				cpu_datain<=ioTG68_DATA;
				if VPA='0' then
					if eclk_fallingedge='1' then
						cpu_clkena<='1';	-- Allow the CPU to run for 1 clock.
						mystate <= readS7; -- If this is a 6800 cycle, we have to wait for eclk.
					end if;
				elsif amiga_eitheredge_read='1' then
					cpu_clkena<='1';	-- Allow the CPU to run for 1 clock.
					U4_1DIR_C <= '0';	-- Set ALVCs to input, and give them time to turn around.
					U4_1OE_C  <= '0';	-- (They should be input already, but it doesn't hurt to be sure.)
					U4_2DIR_C <= '0';
					U4_2OE_C  <= '0';
					mystate <= readS7; -- If this is a 6800 cycle, we have to wait for eclk.
				end if;

			when readS7 =>	
				if amiga_fallingedge_write='1' then -- Rising edge of next S0
					oTG68_ASn   <='1'; -- Release /AS
					oTG68_UDSn  <='1';
					oTG68_LDSn  <='1'; -- Release /UDS and /LDS
					VMA_int <='1'; -- Release VMA

					-- FIXME - This should be delayed until the rising edge of the next S0
					ioTG68_DATA <= (others=>'Z');
--					amiga_addr  <= (others=>'0');
					U1_U2_OE 			<= '1';  -- Render address bus high-z
					mystate <= main;
				end if;		
				
				
			when others =>
				null;

		end case;

	end if;
end process;


oBRn <='1';
oBGACKn <= '1';
--halt_b <= '1';
--reset_b <= '1';

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

-- mysdram : component sdram_simple
mysdram : component sdram
port map
	(
	-- Physical connections to the SDRAM
		pins_io => sdram_pins_io,
		pins_o => sdram_pins_o,
--		sdata => SDRAM_DQ,
--		sdaddr => SDRAM_A,
--		sd_we	=> SDRAM_WE,
--		sd_ras => SDRAM_RAS,
--		sd_cas => SDRAM_CAS,
--		sd_cs	=> SDRAM_CS,
--		dqm(1) => SDRAM_DQMH,
--		dqm(0) => SDRAM_DQML,
--		ba=>SDRAM_BA,

	-- Housekeeping
		sysclk => sysclk,
		sdram_clk => sdram_clk,
		reset => TG68_RESETn,
		reset_out => sdram_ready,

		-- Port 1
		port1_i => fastram_fromcpu,
		port1_o => fastram_tocpu
	);
	
-- tofromsdram.data <= SDRAM_DQ;
--SDRAM_A <= tosdram.addr;
--SDRAM_WE <= tosdram.we;
--SDRAM_RAS <= tosdram.ras;
--SDRAM_CAS <= tosdram.cas;
--SDRAM_CS <= tosdram.cs;
--SDRAM_DQMH <= tosdram.dqm(1);
--SDRAM_DQML <= tosdram.dqm(0);
--SDRAM_BA <= tosdram.ba;

fastram_fromcpu.wr<=cpu_r_w;
fastram_fromcpu.data<=cpu_dataout;
fastram_fromcpu.addr<=sdram_addr&'0';
fastram_fromcpu.uds<=cpu_uds;
fastram_fromcpu.lds<=cpu_lds;
	
END;
