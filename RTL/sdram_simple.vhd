------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                                                                          --
-- Copyright (c) 2009 Tobias Gubener                                        -- 
-- Subdesign fAMpIGA by TobiFlex                                            --
--                                                                          --
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU General Public License as published        --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
--                                                                          --
------------------------------------------------------------------------------
------------------------------------------------------------------------------

-- Simplified 16-bit SDRAM controller for testing purposes.
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.ALL;

library work;
use work.sdram_pkg.ALL;

entity sdram_simple is
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
end;

architecture rtl of sdram_simple is


signal initstate	:unsigned(3 downto 0);	-- Counter used to initialise the RAM
signal cas_sd_cs	:std_logic;	-- Temp registers...
signal cas_sd_ras	:std_logic;
signal cas_sd_cas	:std_logic;
signal cas_sd_we 	:std_logic;
signal cas_dqm		:std_logic_vector(1 downto 0);	-- ...mask register for entire burst
signal init_done	:std_logic :='0';
signal datain		:std_logic_vector(15 downto 0);
signal casaddr		:std_logic_vector(31 downto 0);
signal sdwrite 		:std_logic;
signal sdata_reg	:std_logic_vector(15 downto 0);

signal refreshcycle :std_logic;

type sdram_states is (ph0,ph1,ph2,ph3,ph4,ph5,ph6,ph7,ph8,ph9,ph10,ph11,ph12,ph13,ph14,ph15);
signal sdram_state		: sdram_states;

type sdram_ports is (idle,refresh,port0,port1,zpu,writecache);

signal sdram_slot1 : sdram_ports :=refresh;
signal sdram_slot1_readwrite : std_logic;
signal sdram_slot2 : sdram_ports :=idle;
signal sdram_slot2_readwrite : std_logic;

-- Since VGA has absolute priority, we keep track of the next bank and disallow accesses
-- to either the current or next bank in the interleaved access slots.
signal slot1_bank : std_logic_vector(1 downto 0) := "00";
signal slot2_bank : std_logic_vector(1 downto 0) := "11";

signal refreshcounter : unsigned(11 downto 0);	-- 12 bits gives us 4096 cycles between refreshes => pretty conservative.
signal refreshpending : std_logic :='0';

signal port1_dtack : std_logic;

type writecache_states is (waitwrite,fill,finish);
signal writecache_state : writecache_states;

signal writecache_addr : std_logic_vector(31 downto 1); -- Burst can start at 16-bit alignment
signal writecache_word0 : std_logic_vector(15 downto 0);
signal writecache_word1 : std_logic_vector(15 downto 0);
signal writecache_dqm : std_logic_vector(3 downto 0);
signal writecache_req : std_logic;
signal writecache_dtack : std_logic;
signal writecache_ack : std_logic;

signal zpu_out : std_logic_vector(31 downto 0);
signal zpu_ack : std_logic;


begin

	process(sysclk)
	begin
	
	port1_o.ack <= port1_dtack and writecache_dtack and zpu_ack; -- and not readcache_dtack;


	if reset='0' then
		writecache_req<='0';
	elsif rising_edge(sysclk) then

		writecache_dtack<='1';

		-- 16-bit variant of writecache for CPU...
		if port1_i.req='1' and port1_i.wr='0' and writecache_req='0' then
			writecache_addr(31 downto 1)<=port1_i.addr(31 downto 1);
			writecache_word0<=port1_i.data;
			writecache_dqm(1 downto 0)<=port1_i.uds&port1_i.lds; -- Are we writing the upper word?
--			writecache_word1<=port1_i.data(15 downto 0);
			writecache_dqm(3 downto 2)<="11";
			writecache_req<='1';
			writecache_dtack<='0';
		end if;
		if writecache_ack='1' then
			writecache_req<='0';
		end if;				
	end if;
end process;

	
-------------------------------------------------------------------------
-- SDRAM Basic
-------------------------------------------------------------------------
	reset_out <= init_done;

	process (sysclk, reset, sdwrite, datain) begin
		IF sdwrite='1' THEN	-- Keep sdram data high impedence if not writing to it.
			sdata <= datain;
		ELSE
			sdata <= "ZZZZZZZZZZZZZZZZ";
		END IF;

		--   sample SDRAM data
		if rising_edge(sysclk) then
			sdata_reg <= sdata;
		END IF;	
		
		if reset = '0' then
			initstate <= (others => '0');
			init_done <= '0';
			sdram_state <= ph0;
			sdwrite <= '0';
		ELSIF rising_edge(sysclk) THEN
			sdwrite <= '0';			

			case sdram_state is	--LATENCY=3
				when ph0 =>	
					if sdram_slot2=writecache then -- port1 and sdram_slot2_readwrite='0' then
						sdwrite<='1';
					end if;
					sdram_state <= ph1;
				when ph1 =>	
					sdram_state <= ph2;
				when ph2 =>
					sdram_state <= ph3;
				when ph3 =>
					sdram_state <= ph4;
				when ph4 =>	sdram_state <= ph5;
					sdwrite <= '1';
				when ph5 => sdram_state <= ph6;
					sdwrite <= '1';
				when ph6 =>	sdram_state <= ph7;
					sdwrite <= '1';
				when ph7 =>	sdram_state <= ph8;
					sdwrite <= '1';
				when ph8 =>	sdram_state <= ph9;
					if sdram_slot1=writecache then -- port1 and sdram_slot1_readwrite='0' then
						sdwrite<='1';
					end if;
					
				when ph9 =>	sdram_state <= ph10;
				when ph10 => sdram_state <= ph11;
				when ph11 => sdram_state <= ph12;
				when ph12 => sdram_state <= ph13;
					sdwrite<='1';
				when ph13 => sdram_state <= ph14;
					sdwrite<='1';
				when ph14 =>
						sdwrite<='1';
						if initstate /= "1111" THEN -- 16 complete phase cycles before we allow the rest of the design to come out of reset.
							initstate <= initstate+1;
						else
							init_done<='1';
						end if;
						sdram_state <= ph15;
				when ph15 => sdram_state <= ph0;
					sdwrite<='1';
				when others => sdram_state <= ph0;
			end case;	
		END IF;	
	end process;		


	
	process (sysclk, initstate, datain, init_done, casaddr, refreshcycle) begin


		if reset='0' then
			sdram_slot1<=refresh;
			sdram_slot2<=idle;
			slot1_bank<="00";
			slot2_bank<="11";
		elsif rising_edge(sysclk) THEN -- rising edge
	
			-- Attend to refresh counter
			refreshcounter<=refreshcounter+X"001";
			if sdram_slot1=refresh then
				refreshcounter<=X"001";
				refreshpending<='0';
			elsif refreshcounter=X"000" then
				refreshpending<='1';
			end if;

			sd_cs <='1';
			sd_ras <= '1';
			sd_cas <= '1';
			sd_we <= '1';
			sdaddr <= (others => 'X');
			ba <= "00";
			dqm <= "00";  -- safe defaults for everything...

			port1_dtack<='1';
			zpu_ack<='1';

			-- The following block only happens during reset.
			if init_done='0' then
				if sdram_state =ph2 then
					case initstate is
						when "0010" => --PRECHARGE
							sdaddr(10) <= '1'; 	--all banks
							sd_cs <='0';
							sd_ras <= '0';
							sd_cas <= '1';
							sd_we <= '0';
						when "0011"|"0100"|"0101"|"0110"|"0111"|"1000"|"1001"|"1010"|"1011"|"1100" => --AUTOREFRESH
							sd_cs <='0'; 
							sd_ras <= '0';
							sd_cas <= '0';
							sd_we <= '1';
						when "1101" => --LOAD MODE REGISTER
							sd_cs <='0';
							sd_ras <= '0';
							sd_cas <= '0';
							sd_we <= '0';
--							ba <= "00";
	--						sdaddr <= "001000100010"; --BURST=4 LATENCY=2
--							sdaddr <= "001000110010"; --BURST=4 LATENCY=3
--							sdaddr <= "001000110000"; --noBURST LATENCY=3
							sdaddr <= (others => '0');
							sdaddr(9 downto 0) <= "0000110010"; --BURST=4 LATENCY=3, BURST WRITES
						when others =>	null;	--NOP
					end case;
				END IF;
			else		

			
-- Time slot control			

				writecache_ack<='0';

				case sdram_state is

					when ph2 => -- ACTIVE for first access slot
						cas_sd_cs <= '0';
						cas_sd_ras <= '1';
						cas_sd_cas <= '1';
						cas_sd_we <= '1';

						sdram_slot1<=idle;
						if refreshpending='1' and sdram_slot2=idle then	-- refreshcycle
							sdram_slot1<=refresh;
							sd_cs <= '0'; --ACTIVE
							sd_ras <= '0';
							sd_cas <= '0'; --AUTOREFRESH
						elsif writecache_req='1'
								and sdram_slot2/=writecache
								and (writecache_addr(4 downto 3)/=slot2_bank or sdram_slot2=idle)
									then
							sdram_slot1<=writecache;
							sdaddr <= writecache_addr(23 downto 11);
							ba <= writecache_addr(4 downto 3);
							slot1_bank <= writecache_addr(4 downto 3);
							cas_dqm <= port1_i.uds&port1_i.lds;
							casaddr <= writecache_addr&"0";
							cas_sd_cas <= '0';
							cas_sd_we <= '0';
							sdram_slot1_readwrite <= '0';
							sd_cs <= '0'; --ACTIVE
							sd_ras <= '0';
						elsif port1_i.req='1' and port1_i.wr='1'
								and sdram_slot2/=zpu
								and (port1_i.addr(4 downto 3)/=slot2_bank or sdram_slot2=idle) then
							sdram_slot1<=zpu;
							sdaddr <= port1_i.addr(23 downto 11);
							ba <= port1_i.addr(4 downto 3);
							slot1_bank <= port1_i.addr(4 downto 3); -- slot1 bank
							casaddr <= port1_i.addr(31 downto 1) & "0";
							cas_sd_cas <= '0';
							cas_sd_we <= '1';
							sdram_slot1_readwrite <= '1';
							sd_cs <= '0'; --ACTIVE
							sd_ras <= '0';
						end if;

						if sdram_slot2=zpu then
--							port1_o.data(31 downto 16)<=sdata_reg;
							port1_o.data(15 downto 0)<=sdata_reg;
							zpu_ack<='0';
						end if;


					when ph3 =>
--						if sdram_slot2=zpu then
--							port1_o.data(15 downto 0)<=sdata_reg;
--							zpu_ack<='0';
--						end if;

					when ph4 =>
						
					when ph5 => -- Read or Write command			
						sdaddr <=  "00100" & casaddr(10 downto 5) & casaddr(2 downto 1) ;--auto precharge
						ba <= casaddr(4 downto 3);
						sd_cs <= cas_sd_cs; 
						sd_ras <= cas_sd_ras;
						sd_cas <= cas_sd_cas;
						sd_we  <= cas_sd_we;
						if sdram_slot1=writecache then
							datain <= writecache_word0;
							dqm <= writecache_dqm(1 downto 0);
							writecache_ack<='1'; -- End write burst after 16 bits.
						end if;

					when ph6 => -- Next word of burst write
						if sdram_slot1=writecache then
							datain <= writecache_word1;
							dqm <= writecache_dqm(3 downto 2);
						end if;

					when ph7 => -- third word of burst write
						if sdram_slot1=writecache then
							dqm <= "11";
						end if;
				
					when ph8 =>
						if sdram_slot1=writecache then
							dqm <= "11";
						end if;

					when ph9 =>

					when ph10 => -- Second access slot...
						cas_sd_cs <= '0';  -- Only the lowest bit has any significance...
						cas_sd_ras <= '1';
						cas_sd_cas <= '1';
						cas_sd_we <= '1';

						sdram_slot2<=idle;
						if refreshpending='1' or sdram_slot1=refresh then
							sdram_slot2<=idle;
						elsif writecache_req='1'
								and sdram_slot1/=writecache
								and (writecache_addr(4 downto 3)/=slot1_bank or sdram_slot1=idle)
									then  -- Safe to use this slot with this bank?
							sdram_slot2<=writecache;
							sdaddr <= writecache_addr(23 downto 11);
							ba <= writecache_addr(4 downto 3);
							slot2_bank <= writecache_addr(4 downto 3);
							cas_dqm <= port1_i.uds&port1_i.lds;
							casaddr <= writecache_addr&"0";
							cas_sd_cas <= '0';
							cas_sd_we <= '0';
							sdram_slot2_readwrite <= '0';
							sd_cs <= '0'; --ACTIVE
							sd_ras <= '0';
						elsif port1_i.req='1' and port1_i.wr='1'
								and sdram_slot1/=zpu
								and (port1_i.addr(4 downto 3)/=slot1_bank or sdram_slot1=idle)
								then  -- Safe to use this slot with this bank?
							sdram_slot2<=zpu;
							sdaddr <= port1_i.addr(23 downto 11);
							ba <= port1_i.addr(4 downto 3);
							slot2_bank <= port1_i.addr(4 downto 3); -- slot1 bank
							casaddr <= port1_i.addr(31 downto 1) & "0";
							cas_sd_cas <= '0';
							cas_sd_we <= '1';
							sdram_slot2_readwrite <= '1';
							sd_cs <= '0'; --ACTIVE
							sd_ras <= '0';
						end if;

						-- Fill - takes effect next cycle.
						if sdram_slot1=zpu then
							port1_o.data(15 downto 0)<=sdata_reg;
							zpu_ack<='0';
						end if;
				
					when ph11 =>
--						if sdram_slot1=zpu then
--							port1_o.data(15 downto 0)<=sdata_reg;
--						end if;

					when ph12 =>
						
					-- Phase 13 - CAS for second window...
					when ph13 =>
						if sdram_slot2/=idle then
							sdaddr <=  "00100" & casaddr(10 downto 5) & casaddr(2 downto 1) ;--auto precharge
							ba <= casaddr(4 downto 3);
							sd_cs <= cas_sd_cs; 

							sd_ras <= cas_sd_ras;
							sd_cas <= cas_sd_cas;
							sd_we  <= cas_sd_we;
							if sdram_slot2=writecache then
								datain <= writecache_word0;
								dqm <= writecache_dqm(1 downto 0);
								writecache_ack<='1'; -- End burst after 16 bits for CPU
							end if;
						end if;

					when ph14 => -- Second word of burst write
						if sdram_slot2=writecache then
							datain <= writecache_word1;
							dqm <= writecache_dqm(3 downto 2);
						end if;

					when ph15 => -- Third word of burst write
						if sdram_slot2=writecache then
							dqm <= "11";
						end if;

					when ph0 => -- Final word of burst write
						if sdram_slot2=writecache then
							dqm <= "11";
						end if;

					when ph1 =>

					when others =>
						null;
						
				end case;

			END IF;	
		END IF;	
	END process;		
END;
