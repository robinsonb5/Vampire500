library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.zpu_config.all;
use work.zpupkg.ALL;

entity ZPUTest is
	generic (
		sdram_rows : integer := 12;
		sdram_cols : integer := 8;
		sysclk_frequency : integer := 1000; -- Sysclk frequency * 10
		spi_maxspeed : integer := 4;	-- lowest acceptable timer DIV7 value
		run_from_ram : boolean := true; -- Do we need to run code from SDRAM
		manifest_file1 : std_logic_vector(31 downto 0) := X"534c4944"; -- "SLID"
		manifest_file2 : std_logic_vector(31 downto 0) := X"45534857" -- "ESHW"
	);
	port (
		clk 			: in std_logic;
		src 			: in std_logic_vector(15 downto 0);
		counter 		: buffer unsigned(15 downto 0);
		reset_in 	: in std_logic;
		keys			: in std_logic_vector(3 downto 0);

		-- VGA
		vga_red 		: out unsigned(7 downto 0);
		vga_green 	: out unsigned(7 downto 0);
		vga_blue 	: out unsigned(7 downto 0);
		vga_hsync 	: out std_logic;
		vga_vsync 	: buffer std_logic;
		vga_window	: out std_logic;

		-- SDRAM
		sdr_data		: inout std_logic_vector(15 downto 0);
		sdr_addr		: out std_logic_vector(11 downto 0);
		sdr_dqm 		: out std_logic_vector(1 downto 0);
		sdr_we 		: out std_logic;
		sdr_cas 		: out std_logic;
		sdr_ras 		: out std_logic;
		sdr_cs		: out std_logic;
		sdr_ba		: out std_logic_vector(1 downto 0);
--		sdr_clk		: out std_logic;
		sdr_cke		: out std_logic;

		-- SPI signals
		spi_miso		: in std_logic;
		spi_mosi		: out std_logic;
		spi_clk		: out std_logic;
		spi_cs 		: out std_logic;
		
		-- UART
		rxd	: in std_logic;
		txd	: out std_logic
	);
end entity;

architecture rtl of ZPUTest is

signal reset : std_logic := '0';
signal reset_counter : unsigned(15 downto 0) := X"FFFF";

-- State machine
type SOCStates is (WAITING,READ1,WRITE1,PAUSE,WAITSPIR,WAITSPIW,VGAREAD,VGAWRITE);
signal currentstate : SOCStates;

-- UART signals

signal ser_txdata : std_logic_vector(7 downto 0);
signal ser_txready : std_logic;
signal ser_rxdata : std_logic_vector(7 downto 0);
signal ser_rxrecv : std_logic;
signal ser_txgo : std_logic;
signal ser_rxint : std_logic;
signal ser_clock_divisor : unsigned(15 downto 0);

-- Millisecond counter
signal millisecond_counter : unsigned(31 downto 0) := X"00000000";
signal millisecond_tick : unsigned(19 downto 0);

-- SPI Clock counter
signal spi_tick : unsigned(8 downto 0);
signal spiclk_in : std_logic;
signal spi_fast : std_logic;

-- SPI signals
signal host_to_spi : std_logic_vector(7 downto 0);
signal spi_to_host : std_logic_vector(31 downto 0);
signal spi_wide : std_logic;
signal spi_trigger : std_logic;
signal spi_busy : std_logic;

-- ZPU signals

signal mem_busy           : std_logic;
signal mem_read             : std_logic_vector(wordSize-1 downto 0);
signal mem_write            : std_logic_vector(wordSize-1 downto 0);
signal mem_addr             : std_logic_vector(maxAddrBitIncIO downto 0);
signal mem_writeEnable      : std_logic; 
signal mem_writeEnableh      : std_logic; 
signal mem_writeEnableb      : std_logic; 
signal mem_readEnable       : std_logic;
--signal mem_writeMask        : std_logic_vector(wordBytes-1 downto 0);
signal zpu_enable               : std_logic;
signal zpu_interrupt            : std_logic;
signal zpu_break                : std_logic;

signal zpu_to_rom : ZPU_ToROM;
signal zpu_from_rom : ZPU_FromROM;

signal cpu_uds	: std_logic;
signal cpu_lds : std_logic;

-- VGA controller signals

signal vga_addr : std_logic_vector(31 downto 0);
signal vga_data : std_logic_vector(15 downto 0);
signal vga_req : std_logic;
signal vga_fill : std_logic;
signal vga_refresh : std_logic;
signal vga_newframe : std_logic;
signal vga_reservebank : std_logic; -- Keep bank clear for instant access.
signal vga_reserveaddr : std_logic_vector(31 downto 0); -- to SDRAM

-- VGA register block signals

signal vga_reg_addr : std_logic_vector(11 downto 0);
signal vga_reg_dataout : std_logic_vector(15 downto 0);
signal vga_reg_datain : std_logic_vector(15 downto 0);
signal vga_reg_rw : std_logic;
signal vga_reg_req : std_logic;
signal vga_reg_dtack : std_logic;
signal vga_ack : std_logic;
signal vblank_int : std_logic;


-- External RAM signal (actually M4k for now)

signal externram_wren : std_logic;
signal externram_data : std_logic_vector(wordSize-1 downto 0);
-- signal externram_writedata : std_logic_vector(wordSize-1 downto 0);

-- SDRAM signals

signal sdr_ready : std_logic;
signal sdram_write : std_logic_vector(31 downto 0); -- 32-bit width for ZPU
signal sdram_addr : std_logic_vector(31 downto 0);
signal sdram_req : std_logic;
signal sdram_wr : std_logic;
signal sdram_read : std_logic_vector(31 downto 0);
signal sdram_ack : std_logic;

signal sdram_wrL : std_logic;
signal sdram_wrU : std_logic;
signal sdram_wrU2 : std_logic;

type sdram_states is (read1, read2, read3, write1, writeb, write2, write3, idle);
signal sdram_state : sdram_states;

--

begin

sdr_cke <='1';

-- Timer
process(clk)
begin
	if rising_edge(clk) then
		millisecond_tick<=millisecond_tick+1;
		if millisecond_tick=sysclk_frequency*100 then
			millisecond_counter<=millisecond_counter+1;
			millisecond_tick<=X"00000";
		end if;
	end if;
end process;


-- SPI Timer
process(clk)
begin
	if rising_edge(clk) then
		spiclk_in<='0';
		spi_tick<=spi_tick+1;
		if (spi_fast='1' and spi_tick(3)='1') or spi_tick(8)='1' then
			spiclk_in<='1'; -- Momentary pulse for SPI host.
			spi_tick<='0'&X"00";
		end if;
	end if;
end process;


-- SDRAM
mysdram : entity work.sdram 
	generic map
	(
		rows => sdram_rows,
		cols => sdram_cols
	)
	port map
	(
	-- Physical connections to the SDRAM
		sdata => sdr_data,
		sdaddr => sdr_addr,
		sd_we	=> sdr_we,
		sd_ras => sdr_ras,
		sd_cas => sdr_cas,
		sd_cs	=> sdr_cs,
		dqm => sdr_dqm,
		ba	=> sdr_ba,

	-- Housekeeping
		sysclk => clk,
		reset => reset_in,  -- Contributes to reset, so have to use reset_in here.
		reset_out => sdr_ready,

		vga_addr => vga_addr,
		vga_data => vga_data,
		vga_fill => vga_fill,
		vga_req => vga_req,
		vga_ack => vga_ack,
		vga_refresh => vga_refresh,
		vga_reservebank => vga_reservebank,
		vga_reserveaddr => vga_reserveaddr,

		vga_newframe => vga_newframe,

		datawr1 => sdram_write,
		Addr1 => sdram_addr,
		req1 => sdram_req,
		wr1 => sdram_wr, -- active low
		wrL1 => sdram_wrL, -- lower byte
		wrU1 => sdram_wrU, -- upper byte
		wrU2 => sdram_wrU2, -- upper halfword, only written on longword accesses
		dataout1 => sdram_read,
		dtack1 => sdram_ack
	);

-- Video
	
	myvga : entity work.vga_controller
		generic map (
			enable_sprite => false
		)
		port map (
		clk => clk,
		reset => reset,

		reg_addr_in => mem_addr(11 downto 0),
		reg_data_in => mem_write,
		reg_data_out => vga_reg_dataout,
		reg_rw => vga_reg_rw,
		reg_uds => cpu_uds,
		reg_lds => cpu_lds,
		reg_dtack => vga_reg_dtack,
		reg_req => vga_reg_req,

		sdr_addrout => vga_addr,
		sdr_datain => vga_data, 
		sdr_fill => vga_fill,
		sdr_req => vga_req,
		sdr_ack => vga_ack,
		sdr_reservebank => vga_reservebank,
		sdr_reserveaddr => vga_reserveaddr,
		sdr_refresh => vga_refresh,

		hsync => vga_hsync,
		vsync => vga_vsync,
		vblank_int => vblank_int,
		red => vga_red,
		green => vga_green,
		blue => vga_blue,
		vga_window => vga_window
	);
	


process(clk)
begin
	if reset_in='0' then
		reset_counter<=X"FFFF";
		reset<='0';
	elsif rising_edge(clk) then
		reset_counter<=reset_counter-1;
		if reset_counter=X"0000" then
			reset<='1' and sdr_ready;
		end if;
	end if;
end process;


-- UART

	myuart : entity work.simple_uart
		generic map(
			enable_tx=>true,
			enable_rx=>true
		)
		port map(
			clk => clk,
			reset => reset, -- active low
			txdata => ser_txdata,
			txready => ser_txready,
			txgo => ser_txgo,
			rxdata => ser_rxdata,
			rxint => ser_rxint,
			txint => open,
			clock_divisor => ser_clock_divisor,
			rxd => rxd,
			txd => txd
		);

-- SPI host
spi : entity work.spi_interface
	port map(
		sysclk => clk,
		reset => reset,

		-- Host interface
		spiclk_in => spiclk_in,
		host_to_spi => host_to_spi,
		spi_to_host => spi_to_host,
		wide => spi_wide,
		trigger => spi_trigger,
		busy => spi_busy,

		-- Hardware interface
		miso => spi_miso,
		mosi => spi_mosi,
		spiclk_out => spi_clk

	);

-- Boot ROM - RS232

--	myrom : entity work.RS232Bootstrap_ROM
--	port map (
--		clk => clk,
--		from_zpu => zpu_to_rom,
--		to_zpu => zpu_from_rom
--	);

-- Boot ROM - SD Card
	myrom : entity work.SDRAMTest_ROM
	port map (
		clk => clk,
		from_zpu => zpu_to_rom,
		to_zpu => zpu_from_rom
	);
	

-- Main CPU

	zpu: zpu_core 
	generic map (
		IMPL_MULTIPLY => true,
		IMPL_COMPARISON_SUB => true,
		IMPL_EQBRANCH => true,
		IMPL_STOREBH => false,
		IMPL_LOADBH => false,
		IMPL_CALL => true,
		IMPL_SHIFT => true,
		IMPL_XOR => true,
		REMAP_STACK => true,
		EXECUTE_RAM => run_from_ram -- We can save some LEs by omitting Execute from RAM support
	)
	port map (
		clk                 => clk,
		reset               => not reset,
		enable              => zpu_enable,
		in_mem_busy         => mem_busy,
		mem_read            => mem_read,
		mem_write           => mem_write,
		out_mem_addr        => mem_addr,
		out_mem_writeEnable => mem_writeEnable,
		out_mem_hEnable     => mem_writeEnableh,
		out_mem_bEnable     => mem_writeEnableb,
		out_mem_readEnable  => mem_readEnable,
--		mem_writeMask       => mem_writeMask,
		interrupt           => zpu_interrupt,
		break               => zpu_break,
		from_rom => zpu_from_rom,
		to_rom => zpu_to_rom
	);


process(clk)
begin
	zpu_enable<='1';
	zpu_interrupt<='0';

	if reset='0' then
		currentstate<=WAITING;
		sdram_state<=idle;
		spi_cs<='1';
	elsif rising_edge(clk) then
		mem_busy<='1';

		ser_txgo<='0';

		vga_reg_rw<='1';
		vga_reg_req<='0';
		
		spi_trigger<='0';
		
		case currentstate is
			when WAITING =>
			
				-- Write from CPU
				if mem_writeEnable='1' then
					case mem_addr(31 downto 28) is
--						when X"0000" =>	-- Boot BlockRAM
--							currentstate<=WRITE1;
						when X"E" =>	-- VGA controller
							vga_reg_rw<='0';
							vga_reg_req<='1';
							currentstate<=VGAWRITE;

						when X"F" =>	-- Peripherals
							case mem_addr(7 downto 0) is
								when X"84" => -- UART
									ser_txdata<=mem_write(7 downto 0);
									ser_txgo<='1';
									mem_busy<='0';

								when X"88" => -- UART Clock divisor
									ser_clock_divisor<=unsigned(mem_write(15 downto 0));
									mem_busy<='0';

								when X"8C" => -- Flags (switches) register
									-- Set external signals here
									mem_busy<='0';
									
								when X"90" => -- HEX display
									counter<=unsigned(mem_write(15 downto 0));
									mem_busy<='0';

								when X"C4" => -- SPI CS
									spi_cs<=not mem_write(0);
									spi_fast<=mem_write(8);
									mem_busy<='0';

								when X"C8" => -- SPI write (blocking)
									spi_wide<='0';
									spi_trigger<='1';
									host_to_spi<=mem_write(7 downto 0);
									currentstate<=WAITSPIW;
									
								when X"CC" => -- SPI write wide (blocking)
									spi_wide<='1';
									spi_trigger<='1';
									host_to_spi<=mem_write(7 downto 0);
									currentstate<=WAITSPIW;
									
								when others =>
									mem_busy<='0'; -- FIXME - shouldn't need this
									null;
							end case;
						when others => -- SDRAM access
							sdram_wrL<=mem_writeEnableb and not mem_addr(0);
							sdram_wrU<=mem_writeEnableb and mem_addr(0);
							sdram_wrU2<=mem_writeEnableh or mem_writeEnableb; -- Halfword access
							if mem_writeEnableb='1' then
								sdram_state<=writeb;
							else
								sdram_state<=write1;
							end if;
					end case;

				elsif mem_readEnable='1' then
					case mem_addr(31 downto 28) is

						when X"F" =>	-- Peripherals
							case mem_addr(7 downto 0) is
								when X"84" => -- UART
									mem_read<=(others=>'X');
									mem_read(9 downto 0)<=ser_rxrecv&ser_txready&ser_rxdata;
									ser_rxrecv<='0';	-- Clear rx flag.
									mem_busy<='0';
									
								when X"8C" => -- Flags (switches) register
									mem_read<="XXXXXXXXXXXXXXXX"&src;
									mem_busy<='0';

								when X"C0" => -- Millisecond counter
									mem_read<=std_logic_vector(millisecond_counter);
									mem_busy<='0';

								when X"C4" => -- SPI_CS
									mem_read<=(others=>'X');
									mem_read(15)<=spi_busy;
									mem_busy<='0';
									
								when X"C8" => -- SPI read (blocking)
									spi_wide<='0';
									currentstate<=WAITSPIR;

								when X"CC" => -- SPI read (blocking)
									spi_wide<='1';
									spi_trigger<='1';
									host_to_spi<=X"FF";
									currentstate<=WAITSPIR;

								when X"F8" => -- Filename 1
									mem_read(31 downto 0)<=manifest_file1; -- "SLID"
									mem_busy<='0';

								when X"FC" => -- Filename 2
									mem_read(31 downto 0)<=manifest_file2; -- "ESHW"
									mem_busy<='0';

								when others =>
									mem_busy<='0'; -- FIXME - shouldn't need this
									null;
							end case;

						when others => -- SDRAM
							sdram_state<=read1;
					end case;
				end if;

			when VGAWRITE =>
				if vga_reg_dtack='0' then
					mem_busy<='0';
					currentstate<=WAITING;
				end if;

			when WAITSPIW =>
				if spi_busy='0' then
					mem_busy<='0';
					currentstate<=WAITING;
				end if;

			when WAITSPIR =>
				mem_read<=spi_to_host;
				if spi_busy='0' then
					mem_busy<='0';
					currentstate<=WAITING;
				end if;

			when PAUSE =>
				currentstate<=WAITING;

			when others =>
				currentstate<=WAITING;
				null;
		end case;
	
	-- SDRAM state machine
	
		case sdram_state is
			when read1 => -- read first word from RAM
				sdram_addr<=mem_Addr;
				sdram_wr<='1';
				sdram_req<='1';
				if sdram_ack='0' then
					mem_read<=sdram_read;
					sdram_req<='0';
					sdram_state<=idle;
					mem_busy<='0';
				end if;
			when write1 => -- write 32-bit word to SDRAM
				sdram_addr<=mem_Addr;
				sdram_wr<='0';
				sdram_req<='1';
				sdram_write<=mem_write; -- 32-bits now
				if sdram_ack='0' then -- done?
					sdram_req<='0';
					sdram_state<=idle;
					mem_busy<='0';
				end if;
			when writeb => -- write 8-bit value to SDRAM
				sdram_addr<=mem_Addr;
				sdram_wr<='0';
				sdram_req<='1';
				sdram_write<=mem_write; -- 32-bits now
				sdram_write(15 downto 8)<=mem_write(7 downto 0); -- 32-bits now
				if sdram_ack='0' then -- done?
					sdram_req<='0';
					sdram_state<=idle;
					mem_busy<='0';
				end if;
			when others =>
				null;

		end case;

		-- Set this after the read operation has potentially cleared it.
		if ser_rxint='1' then
			ser_rxrecv<='1';
		end if;

	end if; -- rising-edge(clk)

end process;
	
end architecture;
