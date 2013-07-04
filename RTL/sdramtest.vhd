library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.ALL;

library altera;
use altera.altera_syn_attributes.all;

library work;
use work.sdram_pkg.all;


entity sdramtest is
generic
	(
		rows : integer := 12;	-- FIXME - change access sizes according to number of rows
		cols : integer := 8
	);
port(
		clk 	: in 	std_logic;
		reset_n : in 	std_logic;
		led_out : out 	std_logic;
		errorbits : out std_logic_vector(15 downto 0);

		-- SDRAM - chip 1
		sdr_addr : out std_logic_vector((rows-1) downto 0);
		sdr_data : inout std_logic_vector(15 downto 0);
		sdr_ba : out std_logic_vector(1 downto 0);
		sdr_cke : out std_logic;
		sdr_dqm : out std_logic_vector(1 downto 0);
		sdr_cs : out std_logic;
		sdr_we : out std_logic;
		sdr_cas : out std_logic;
		sdr_ras : out std_logic
	);
end sdramtest;

architecture RTL of sdramtest is

signal reset : std_logic :='0';
signal sdr_ready : std_logic;
signal sdram_fromcpu : SDRAM_Port_FromCPU;
signal sdram_tocpu : SDRAM_Port_ToCPU;

signal ena : std_logic;
signal dtack : std_logic;
signal req_pending : std_logic;
signal ramaddress : std_logic_vector(23 downto 0);
signal datatoram : std_logic_vector(15 downto 0);
signal datafromram : std_logic_vector(15 downto 0);
signal expected_data :std_logic_vector(15 downto 0);

signal ramrw : std_logic;

type sdrstate is (init,write1,write2,write3,write4,read1,read2,read3,read4,waitread,waitram,waitkey,
	burstwrite1,burstwrite2,burstwrite3,burstwrite4);
signal ramstate : sdrstate;
signal nextstate : sdrstate;

signal reset_counter : unsigned(15 downto 0):=X"0000";
signal ready : std_logic :='0';

signal lfsr_reset : std_logic;
signal lfsr_ena : std_logic;
signal lfsr_data : std_logic_vector(21 downto 0);

signal testcounter : unsigned(15 downto 0);
signal error : std_logic;

COMPONENT simplelfsr
	PORT
	(
		clk		:	 IN STD_LOGIC;
		reset		:	 IN STD_LOGIC;
		ena		:	 IN STD_LOGIC;
		lfsr		:	 OUT STD_LOGIC_VECTOR(21 DOWNTO 0)
	);
END COMPONENT;

begin

	sdr_cke<='1';

	mylfsr : component simplelfsr
		port map (
        clk => clk,
        reset => lfsr_reset or not reset,
        ena => lfsr_ena,
        lfsr => lfsr_data
	  );

	process(clk)
	begin
		ready <= reset and sdr_ready;
		if rising_edge(clk) then
			reset_counter<=reset_counter+1;
			if reset_counter+1=X"0000" then
				reset<='1';
			end if;
			if reset_n='0' then
				reset<='0';
				reset_counter<=X"0000";
			end if;
		end if;
	end process;


	process(clk)
	begin
		if ready='0' then
			req_pending<='0';
			ramrw<='1';
			ramstate<=init;
			lfsr_ena<='0';
			lfsr_reset<='1';
			error<='0';
			testcounter<=X"FFFF";
		elsif rising_edge(clk) then
		
			lfsr_reset<='0';
			
			led_out<=not error;

			case ramstate is
				when init =>
					req_pending<='0';
					ramstate<=write1;
				when write1 =>
					ramaddress<='0'&lfsr_data&'0';
					datatoram<=lfsr_data(15 downto 0);
					ramrw<='0';
					req_pending<='1';
					nextstate<=write2;
					ramstate<=waitram;
				when write2 =>
					ramaddress(1)<=not lfsr_data(0);
					datatoram<=lfsr_data(15 downto 0) xor X"0001";
					ramrw<='0';
					req_pending<='1';
					nextstate<=write3;
					ramstate<=waitram;
				when write3 =>
					testcounter<=testcounter-1;
					lfsr_ena<='1';
					ramstate<=write4;
					if testcounter=X"0001" then
						lfsr_reset<='1';
					end if;
				when write4 =>
					lfsr_ena<='0';
					if testcounter=X"0000" then
						ramstate<=read1;
						testcounter<=X"FFFF";
					else
						ramstate<=write1;
					end if;

				when read1 =>
					ramaddress<='0'&lfsr_data&'0';
					req_pending<='1';
					nextstate<=read2;
					ramstate<=waitram;
					expected_data <= lfsr_data(15 downto 0);
				when read2 =>
					error<='0';
					if datafromram /= expected_data then
						errorbits<=datafromram xor expected_data;
						error<='1';
					end if;
					ramaddress(1)<=not lfsr_data(0);
					req_pending<='1';
					nextstate<=read3;
					ramstate<=waitram;
					expected_data(0) <= not lfsr_data(0);
				when read3 =>
					if datafromram /= expected_data then
						errorbits<=datafromram xor expected_data;
--					if datafromram /= lfsr_data(15 downto 0) then
						error<='1';
					end if;
					testcounter<=testcounter-1;
					lfsr_ena<='1';
					ramstate<=read4;
					if testcounter=X"0001" then
						lfsr_reset<='1';
					end if;
				when read4 =>
					lfsr_ena<='0';
					if testcounter=X"0000" then
						ramstate<=write1;
						testcounter<=X"FFFF";
					else
						ramstate<=read1;
					end if;

				when waitram =>
					if ena='1' then
						ramstate<=nextstate;
						req_pending<='0';
						ramrw<='1';
					end if;
				when others =>
					null;
			end case;
		end if;

	end process;

	-- SDRAM
	mysdram_simple : entity work.sdram_simple
		generic map
		(
			rows => rows,
			cols => cols
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
			reset => reset,
			reset_out => sdr_ready,

			port1_i => sdram_fromcpu,
			port1_o => sdram_tocpu
		);

sdram_fromcpu.req<=req_pending;
sdram_fromcpu.wr<=ramrw;
sdram_fromcpu.data<=datatoram;
sdram_fromcpu.addr<="000000000"&ramaddress(22 downto 1)&'1';
sdram_fromcpu.uds<='0';
sdram_fromcpu.lds<='0';
datafromram <= sdram_tocpu.data;
ena <= not sdram_tocpu.ack;

end RTL;

