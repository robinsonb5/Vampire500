library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.zpu_config.all;
use work.zpupkg.ALL;
use work.sdram_pkg.all;

entity MemChecker is
	port (
		clk 			: in std_logic;
		sdram_clk	: in std_logic;
		reset_in 	: in std_logic;

		-- SDRAM
		sdram_pins_io : inout SDRAM_Pins_io;
		sdram_pins_o : out SDRAM_Pins_o;

		-- Debug channel signals
		debug_out : out std_logic_vector(7 downto 0);
		debug_req : out std_logic;
		debug_ack : in std_logic
	);
end entity;

architecture rtl of MemChecker is

signal reset : std_logic := '0';
signal reset_counter : unsigned(15 downto 0) := X"FFFF";
signal sdr_ready : std_logic;

-- State machine
type SOCStates is (WAITING,READ1,WRITE1,PAUSE,WAITSPIR,WAITSPIW,VGAREAD,VGAWRITE);
signal currentstate : SOCStates := WAITING;

-- UART signals

signal ser_txdata : std_logic_vector(7 downto 0);
signal ser_txready : std_logic;


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


-- External RAM signal (actually M4k for now)

-- SDRAM signals

type sdram_states is (read1, read2, read3, write1, writeb, write2, write3, idle);
signal sdram_state : sdram_states;

signal sdram_port_fromcpu : SDRAM_Port_FromCPU;
signal sdram_port_tocpu : SDRAM_Port_ToCPU;

--

begin

debug_req<=not ser_txready;

-- SDRAM
mysdram : entity work.sdram 
	port map
	(
	-- Physical connections to the SDRAM
		pins_o => sdram_pins_o,
		pins_io => sdram_pins_io,

	-- Housekeeping
		sysclk => clk,
		sdram_clk => sdram_clk,
		reset => reset_in,  -- Contributes to reset, so have to use reset_in here.
		reset_out => sdr_ready,

		-- Port 1
		port1_i => sdram_port_fromcpu,
		port1_o => sdram_port_tocpu
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


-- Boot ROM - Memory tester
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
		EXECUTE_RAM => false -- We can save some LEs by omitting Execute from RAM support
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
	elsif rising_edge(clk) then
		mem_busy<='1';

		if debug_ack='1' then
			ser_txready<='1';
		end if;
		
		case currentstate is
			when WAITING =>
			
				-- Write from CPU
				if mem_writeEnable='1' then
					case mem_addr(31 downto 28) is

						when X"F" =>	-- Peripherals
							case mem_addr(7 downto 0) is
								when X"84" => -- UART
									debug_out<=mem_write(7 downto 0);
									ser_txready<='0';
									mem_busy<='0';

								when others =>
									mem_busy<='0'; -- FIXME - shouldn't need this
									null;
							end case;
						when others => -- SDRAM access
							sdram_state<=write1;
					end case;

				elsif mem_readEnable='1' then
					case mem_addr(31 downto 28) is

						when X"F" =>	-- Peripherals
							case mem_addr(7 downto 0) is
								when X"84" => -- UART
									mem_read<=(others=>'X');
									mem_read(9 downto 0)<='0'&ser_txready&X"00";
									mem_busy<='0';

								when others =>
									mem_busy<='0'; -- FIXME - shouldn't need this
									null;
							end case;

						when others => -- SDRAM
							sdram_state<=read1;
					end case;
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
				sdram_port_fromcpu.addr<=mem_Addr;
				sdram_port_fromcpu.wr<='1';
				sdram_port_fromcpu.req<='1';
				if sdram_port_tocpu.ack='0' then
					mem_read(31 downto 16)<=sdram_port_tocpu.data;
					sdram_port_fromcpu.req<='0';
					sdram_state<=read2;
				end if;
			when read2 =>
				if sdram_port_tocpu.ack='1' then
					sdram_state<=read3;
				end if;
			when read3 => -- read second word from RAM
				sdram_port_fromcpu.addr(1)<=not mem_Addr(1);
				sdram_port_fromcpu.wr<='1';
				sdram_port_fromcpu.req<='1';
				if sdram_port_tocpu.ack='0' then
					mem_read(15 downto 0)<=sdram_port_tocpu.data;
					sdram_port_fromcpu.req<='0';
					sdram_state<=idle;
					mem_busy<='0';
				end if;
			when write1 => -- write first half of 32-bit word to SDRAM
				sdram_port_fromcpu.addr<=mem_Addr;
				sdram_port_fromcpu.data<=mem_write(31 downto 16);
				sdram_port_fromcpu.wr<='0';
				sdram_port_fromcpu.uds<='0';
				sdram_port_fromcpu.lds<='0';
				sdram_port_fromcpu.req<='1';
				if sdram_port_tocpu.ack='0' then
					sdram_port_fromcpu.req<='0';
					sdram_state<=write2;
				end if;
			when write2 =>
				if sdram_port_tocpu.ack='1' then
					sdram_state<=write3;
				end if;
			when write3 => -- write second half of 32-bit word to SDRAM
				sdram_port_fromcpu.addr(1)<=not mem_Addr(1);
				sdram_port_fromcpu.data<=mem_write(15 downto 0);
				sdram_port_fromcpu.wr<='0';
				sdram_port_fromcpu.uds<='0';
				sdram_port_fromcpu.lds<='0';
				sdram_port_fromcpu.req<='1';
				if sdram_port_tocpu.ack='0' then
					sdram_port_fromcpu.req<='0';
					sdram_state<=idle;
					mem_busy<='0';
				end if;
			when others =>
				null;

		end case;

	end if; -- rising-edge(clk)

end process;

end architecture;
