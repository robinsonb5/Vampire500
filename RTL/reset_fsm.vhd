--
-- Filename: reset_fsm.vhd
-- Author:   Tim Nicholls
-- Date:     October 31, 2012
-- Version:  1.0
-- Abstract: This is the FSM that controls the resetting of the TG68
--           and the bus arbitration between the TG68 and the MC68k CPUs.
--           The boot process is as follows:
--           1. Reset asserted and deasserted to both motherboard and FPGA board.
--           2. MC68k begins its reset exception. The FSM holds the TG68 in reset.
--           3. The MC68k loads is reset vector and stack which takes 4 complete bus cycles and should not be interrupted.
--           4. FSM monitors the MC68k to see when this stage is complete by counting iAS.
--           5. FSM starts and completes the bus arbitration. The MC68k has released the bus.
--           6. TG68 now has the bus and the FSM deasserts reset to the TG68 and the TG68 now loads its reset vectors.
--           7. TG68 is now running the motherboards code.
--
library ieee;
use  IEEE.STD_LOGIC_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity reset_fsm is
   port(
    iCLK_7MHZ     : in  std_logic; -- 7MHz clock
    iRESETn       : in  std_logic; -- Active low reset from Amiga 600 motherboards
    fsm_ena : in std_logic;
	 --
-- MC68k signals
--
    iASn          : in  std_logic; -- MC68k address strobe, active low
    iDTACKn       : in  std_logic; -- MC68k DTACKn
		ioBRn					    : out std_logic; -- Bus Request output to MC68k
		iBGn          : in  std_logic; -- Bus Grant input from MC68k
		oBGACKn			    : out std_logic; -- Bus Grant Acknowledge to the MC68k
--
-- TG68 signals
--
    oTG68_RESETn  : out std_logic  -- TG68 reset, active low
		  );
end reset_fsm;

ARCHITECTURE RTL of reset_fsm is

constant asserted          : std_logic := '0';
constant negated           : std_logic := '1';

type type_fstate is (IDLE, BEGIN_ARBITRATION, WAIT_FOR_BG, ASSERT_BGACK, RELEASE_TG68);
signal CURRENT_STATE       : type_fstate;
signal NEXT_STATE          : type_fstate;
signal MC68_reset_complete : std_logic; --MC68k has completed its reset exception process
signal MC68_cycle_complete : std_logic; -- MC68k bus cycle is complete
signal bus_cycle_count     : std_logic_vector(1 downto 0) := "00"; -- MC68k bus cycle counter out of reset

BEGIN


--  bus_cycle_counter: process (iCLK_7MHZ)
 -- BEGIN
 --     if(iCLK_7MHz'event and iCLK_7MHz = '1') then
  --        if(iRESETn = '0') then
   --           bus_cycle_count <= "00";
  --            MC68_reset_complete <= '0';
   --       elsif (iASn = '0') then
--
   --           bus_cycle_count <= bus_cycle_count + 1;
    --      elsif (iASn = '1' and bus_cycle_count = "11") then
     --         MC68_reset_complete <= '1';        -- Asserted for 1 bus cycle every 4 MC68k bus cycles
     --     else
     --         MC68_reset_complete <= '0';
     --     end if;    
    --  end if;
 -- end process;
  
	--MAJSTA modifications to include fsm_ena signal 
	  bus_cycle_counter: process(iCLK_7MHZ,iRESETn)
   begin
			if iRESETn='0' then
              bus_cycle_count <= "00";
              MC68_reset_complete <= '0';
			elsif(iCLK_7MHZ'event and iCLK_7MHZ='1') then
         if fsm_ena='1' then
			if (iASn = '0') then
				  bus_cycle_count <= bus_cycle_count + 1;         
         elsif (iASn = '1' and bus_cycle_count = "11") then
              MC68_reset_complete <= '1';  -- Asserted for 1 bus cycle every 4 MC68k bus cycles
            end if;
         else
              MC68_reset_complete <= '0';
         end if;
      end if;

   end process;
  
  
  

--process (iCLK_7MHZ)
--    BEGIN
--        if(iCLK_7MHZ'event and iCLK_7MHZ = '1') then
--            if(iRESETn = '0') then
--                MC68_cycle_complete <= '0';
--           elsif(iASn = '1' and iDTACKn = '1' and iBGn = '0') then
--                MC68_cycle_complete <= '1';
--            else
--                MC68_cycle_complete <= '0';
--            end if;
--        end if;
--end process;

--MAJSTA modifications to include fsm_ena signal 

process(iCLK_7MHZ,iRESETn)
   begin
			if iRESETn='0' then
              MC68_cycle_complete <= '0';
			elsif(iCLK_7MHZ'event and iCLK_7MHZ='1') then
         if fsm_ena='1' then
			if (iASn = '1' and iDTACKn = '1' and iBGn = '0') then
				  MC68_cycle_complete <= '1';                    
         end if;
			else
              MC68_cycle_complete <= '0';
         end if;
      end if;

   end process;

--
-- Synchronous portion of the FSM
--
 --  fsm_sync: PROCESS (iCLK_7MHZ)
 --  begin
  --     if (iCLK_7MHZ' event and iCLK_7MHZ = '1') then
	--	       CURRENT_STATE <= NEXT_STATE;			
   --    end if;
  --  end process;
--
-- Combintorial portion of the FSM
--    

-- MAJSTA changed including reset in process because there was problem with latches who remains in previous states
process (iCLK_7MHZ, iRESETn)
begin
if (iRESETn='0') then
  CURRENT_STATE <= IDLE;  --default state on reset.
elsif (rising_edge(iCLK_7MHZ)) then
  CURRENT_STATE <= NEXT_STATE;   --state change.
end if;
end process;

fsm_comb: PROCESS (CURRENT_STATE, NEXT_STATE, iRESETn, MC68_reset_complete, MC68_cycle_complete)
    begin

            case CURRENT_STATE is
                when IDLE => 			                
                    oTG68_RESETn <= '0';             -- Assert TG68 RESET
                    ioBRn   				 <= negated;         -- Negate Bus request
                    oBGACKn      <= negated;         -- Negate Bus Grant Acknowledge
                    if (MC68_reset_complete = '1') then
                        NEXT_STATE <= BEGIN_ARBITRATION; -- If the MC68k has read its reset vectors begin arbitration
                    else                                 -- else
                        NEXT_STATE <= IDLE;              -- remain in the IDLE state
                    end if;

                when BEGIN_ARBITRATION =>
                    oTG68_RESETn <= '0';             -- Assert TG68 RESET
                    ioBRn			     <= asserted;        -- Assert Bus request
                    oBGACKn      <= negated;         -- Negate Bus Grant Acknowledge
 -- MAJSTA disabled   if (ioBRn = '1') then             -- Something else is requesting the MC68k so wait
 --because BR is not  NEXT_STATE <= BEGIN_ARBITRATION;
 --in use on A600     else
                        NEXT_STATE   <= WAIT_FOR_BG;     -- Next state is wait for BUS GRANT
 -- pull-up           end if;

                when WAIT_FOR_BG =>
                    oTG68_RESETn <= '0';             -- Assert TG68 RESET
                    ioBRn	   			 <= asserted;        -- Assert Bus request
                    oBGACKn      <= negated;         -- Negate Bus Grant Acknowledge
                    if (MC68_cycle_complete = '1' ) then
                        oBGACKn    <= asserted;        -- Assert Bus Grant Acknowledge
                        NEXT_STATE <= ASSERT_BGACK;  -- If the MC68k bus cycle has completed assert BGACKn
                    else                             -- else
                        NEXT_STATE <= WAIT_FOR_BG;   -- remain in this state
                    end if;

               when ASSERT_BGACK =>
                    oTG68_RESETn <= '0';             -- Assert TG68 RESET
                    ioBRn	   			 <= negated;         -- Negate Bus request
                    oBGACKn      <= asserted;        -- Assert Bus Grant Acknowledge
                    NEXT_STATE   <= RELEASE_TG68;    -- Remove RESET from TG68

              when RELEASE_TG68 =>
                    oTG68_RESETn <= '1';             -- Negate TG68 RESET
                    ioBRn	   			 <= negated;         -- Negate Bus request
                    oBGACKn      <= asserted;        -- Assert Bus Grant Acknowledge
                    NEXT_STATE   <= RELEASE_TG68;    -- Remain in this state until a reset occures

              when others =>
                    oTG68_RESETn <= '0';             -- Assert TG68 RESET
                    ioBRn	   			 <= negated;         -- Negate Bus request
                    oBGACKn      <= negated;         -- Negate Bus Grant Acknowledge
                    NEXT_STATE   <= IDLE;              
            end case;


    end process;
	 end;