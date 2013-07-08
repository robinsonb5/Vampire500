library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sdram_config.all;

package sdram_pkg is

-- Physical connections to SDRAM

type SDRAM_Pins_io is record
	data : std_logic_vector(15 downto 0);
end record;

type SDRAM_Pins_o is record
	clk : std_logic;
	cke : std_logic; -- Clock enable
	addr : std_logic_vector(sdram_rows-1 downto 0); -- Address - size specified in sdram_config.vhd
	we : std_logic;	-- Write enable, active low
	ras : std_logic;	-- Row Address Strobe, active low
	cas : std_logic;	-- Column Address Strobe, active low
	cs : std_logic;	-- Chip select - only the lsb does anything.
	dqm : std_logic_vector(1 downto 0);	-- Data mask, upper and lower byte
	ba : std_logic_vector(1 downto 0); -- Bank
end record;


-- Logical connections to CPU

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

-- Component definition

component sdram is
port
	(
-- Pinssical connections to the SDRAM
	pins_io : inout SDRAM_Pins_io;	-- Data lines
	pins_o : out SDRAM_Pins_o; -- control signals

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
port
	(
-- Pinssical connections to the SDRAM
	Pins_io : inout SDRAM_Pins_io;	-- Data lines
	Pins_o : out SDRAM_Pins_o; -- control signals

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
