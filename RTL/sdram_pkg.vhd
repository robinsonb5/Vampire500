library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package sdram_pkg is

type SDRAM_Port_FromCPU is record
	data : std_logic_vector(15 downto 0);
	addr : std_logic_vector(31 downto 0);
	req : std_logic;
	wr : std_logic;
	uds : std_logic;
	lds : std_logic;
end record;

type SDRAM_Port_ToCPU is record
	data : std_logic_vector(15 downto 0);
	ack : std_logic;
end record;

component sdram is
generic
	(
		rows : integer := 12;	-- FIXME - change access sizes according to number of rows
		cols : integer := 8
	);
port
	(
-- Physical connections to the SDRAM
	sdata		: inout std_logic_vector(15 downto 0);
	sdaddr		: out std_logic_vector((rows-1) downto 0);
	sd_we		: out std_logic;	-- Write enable, active low
	sd_ras		: out std_logic;	-- Row Address Strobe, active low
	sd_cas		: out std_logic;	-- Column Address Strobe, active low
	sd_cs		: out std_logic;	-- Chip select - only the lsb does anything.
	dqm			: out std_logic_vector(1 downto 0);	-- Data mask, upper and lower byte
	ba			: buffer std_logic_vector(1 downto 0); -- Bank?

-- Housekeeping
	sysclk		: in std_logic;
	reset		: in std_logic;
	reset_out	: out std_logic;
	reinit : in std_logic :='0';

-- Port 0 - VGA
	vga_addr : in std_logic_vector(31 downto 0) := (others => 'X');
	vga_data	: out std_logic_vector(15 downto 0);
	vga_req : in std_logic :='0';
	vga_fill : out std_logic;
	vga_ack : out std_logic;
	vga_refresh : in std_logic:='1'; -- SDRAM won't come out of reset without this.
	vga_reservebank : in std_logic:='0'; -- Keep a bank clear for instant access in slot 1
	vga_reserveaddr : in std_logic_vector(31 downto 0) := (others => 'X');

	-- Port 1
	port1_i : in SDRAM_Port_FromCPU;
	port1_o : out SDRAM_Port_ToCPU
	);
end component;

component sdram_simple is
generic
	(
		rows : integer := 12;	-- FIXME - change access sizes according to number of rows
		cols : integer := 8
	);
port
	(
-- Physical connections to the SDRAM
	sdata		: inout std_logic_vector(15 downto 0);
	sdaddr		: out std_logic_vector((rows-1) downto 0);
	sd_we		: out std_logic;	-- Write enable, active low
	sd_ras		: out std_logic;	-- Row Address Strobe, active low
	sd_cas		: out std_logic;	-- Column Address Strobe, active low
	sd_cs		: out std_logic;	-- Chip select - only the lsb does anything.
	dqm			: out std_logic_vector(1 downto 0);	-- Data mask, upper and lower byte
	ba			: buffer std_logic_vector(1 downto 0); -- Bank?

-- Housekeeping
	sysclk		: in std_logic;
	reset		: in std_logic;
	reset_out	: out std_logic;

	-- Port 1
	port1_i : in SDRAM_Port_FromCPU;
	port1_o : out SDRAM_Port_ToCPU
	);
end component;

end package;
