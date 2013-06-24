
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.zpu_config.all;
use work.zpupkg.ALL;


entity ZPU_Bridge is
	generic(
		SR_Read : integer:= 0;         --0=>user,   1=>privileged,      2=>switchable with CPU(0)
		VBR_Stackframe : integer:= 0;  --0=>no,     1=>yes/extended,    2=>switchable with CPU(0)
		extAddr_Mode : integer:= 0;    --0=>no,     1=>yes,    2=>switchable with CPU(1)
		MUL_Mode : integer := 0;	   --0=>16Bit,  1=>32Bit,  2=>switchable with CPU(1),  3=>no MUL,  
		DIV_Mode : integer := 0;	   --0=>16Bit,  1=>32Bit,  2=>switchable with CPU(1),  3=>no DIV,  
		BitField : integer := 0		   --0=>no,     1=>yes,    2=>switchable with CPU(1)  
		);
   port(clk               	: in std_logic;
        nReset             	: in std_logic;			--low active
        clkena_in         	: in std_logic:='1';
        data_in          	: in std_logic_vector(15 downto 0);
		IPL				  	: in std_logic_vector(2 downto 0):="111";
		IPL_autovector   	: in std_logic:='0';
		CPU             	: in std_logic_vector(1 downto 0):="00";  -- 00->68000  01->68010  11->68020(only some parts - yet)
        addr           		: buffer std_logic_vector(31 downto 0);
        data_write        	: out std_logic_vector(15 downto 0);
		nWr			  		: out std_logic;
		nUDS, nLDS	  		: out std_logic;
		busstate	  	  	: out std_logic_vector(1 downto 0);	-- 00-> fetch code 10->read data 11->write data 01->no memaccess
		nResetOut	  		: out std_logic;
        FC              	: out std_logic_vector(2 downto 0);
-- for debug		
		skipFetch	  		: out std_logic;
        regin          		: buffer std_logic_vector(31 downto 0)
        );
end ZPU_Bridge;

architecture rtl of ZPU_Bridge is

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

begin

	myrom : entity work.VampireDiag_ROM
	port map (
		clk => clk,
		from_zpu => zpu_to_rom,
		to_zpu => zpu_from_rom
	);

	zpu: zpu_core 
	generic map (
		IMPL_MULTIPLY => true,
		IMPL_COMPARISON_SUB => true,
		IMPL_EQBRANCH => true,
		IMPL_STOREBH => true,
		IMPL_LOADBH => true,
		IMPL_CALL => true,
		IMPL_SHIFT => true,
		IMPL_XOR => true,
		REMAP_STACK => false, -- Shouldn't need to access the stack by address for simple testcases
		EXECUTE_RAM => false -- Shouldn't need to execute insructions from external RAM in simple testcases
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
		out_mem_hEnable     => mem_hEnable,
		out_mem_bEnable     => mem_bEnable,
		out_mem_readEnable  => mem_readEnable,
--		mem_writeMask       => mem_writeMask,
		interrupt           => zpu_interrupt,
		break               => zpu_break,
		from_rom => zpu_from_rom,
		to_rom => zpu_to_rom
	);

zpu_enable<='1';
zpu_interrupt<='0';

process(clk)
begin
	nResetOut<=nReset;
	mem_busy<='1';
	if nReset='0' then
		state<=waiting;
	elsif rising_edge(clk) then
		case state is
			when waiting =>
				if clkena_in='1' then -- Sync with toplevel state machine
					if mem_writeEnable='1' then
						-- Trigger write of either high word, or single word if half or byte cycle.

						if mem_hEnable='1' then	-- Halfword cycle
							data_write<=mem_write(15 downto 0);
							nUDS='0';
							nLDS='0';
							state<=writelow;
							
						elsif mem_bEnable='1' then -- Byte cycle
							data_write<=mem_write(15 downto 0);
							nUDS=not mem_addr(0);
							nLDS=mem_addr(0);
							state<=writelow;
							
						else	-- longword cycle.
							addr<=zpu_addr(31 downto 2)&"00";
							data_write<=mem_write(31 downto 16);
							nUDS='0';
							nLDS='0';
							state<=writehigh;
						end if;

						nWR='0';
						busstate<="11";
					
					elsif mem_readEnable='1' then
						-- Trigger read of either high word, or single word if half or byte cycle.
						if mem_hEnable='1' then	-- Halfword cycle
						
						elsif mem_bEnable='1' then -- Byte cycle
						
						else	-- longword cycle.
						
						end if;
					
					end if;
				end if;

			when readhigh =>

			when readlow =>
			
			when writehigh =>
				if clkena_in='1' then
					addr(1)='1';
					data_write<=mem_write(15 downto 0);
				end if;
				state<=writelow;
			
			when writelow =>
				if clkena_in='1' then
					busstate<='01'; -- Do nothing
					nWR<='1';
					mem_busy<='0';	-- Allow ZPU to continue
				end if;
				state<=writelow;
			
	end if;
end process;

end architecture;
