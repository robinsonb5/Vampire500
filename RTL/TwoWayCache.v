// Two Way Cache, supporting 64 meg address space.
// Would be easy enough to extend to wider address spaces, just need
// to increase the width of the "tag" blockram.

// If we're targetting Cyclone 3, then we have 9kbit blockrams to play with.
// Each burst, assuming we stick with 4-word bursts, is 64 bits, so a single M9K
// can hold 128 cachelines.  Since we're building a 2-way cache, this will end
// up being 2 overlapping sets of 64 cachelines.

// (In fact we end up using a single M9K for tag RAM, which gives us 512 cachelines,
// as two sets of 256.)

// The address is broken down as follows:
//   bit 0 is irrelevant because we're working in 16-bit words.
//   bits 2:1 specify which word of a burst we're interested in.
//   Bits 10:3 specify the eight bit address of the cachelines;
//     this will map to {1'b0,addr[10:3]} and {1;b1,addr[10:3]} respectively.
//   Bits 25:11 have to be stored in the tag, which, it turns out is no problem,
//     since we can use have 18-bit wide words.  The highest bit will be used as
//     a "most recently used" flag, leaving one bit spare, so we can support 64 meg
//     without changing bit widths.
// (Storing the MRU flag in both tags in a 2-way cache is redundant, so we'll only 
// store it in the first tag.)

module TwoWayCache
(
	input clk,
	input reset, // active low
	output ready,
	input [31:0] cpu_addr,
	input cpu_req,	// 1 to request attention
	output reg cpu_ack,	// 1 to signal that data is ready.
	input cpu_rw, // 1 for read cycles, 0 for write cycles
	input cpu_rwl,
	input cpu_rwu,
	input [15:0] data_from_cpu,
	output reg [15:0] data_to_cpu,
	output reg [31:0] sdram_addr,
	input [15:0] data_from_sdram,
	output reg [15:0] data_to_sdram,
	output reg sdram_req,
	input sdram_fill,
	output reg sdram_rw	// 1 for read cycles, 0 for write cycles
);

// States for state machine
parameter WAITING=0, WAITRD=1, WAITFILL=2,
				FILL2=3, FILL3=4, FILL4=5, FILL5=6, PAUSE1=7,
				WRITE1=8, WRITE2=9, INIT1=10, INIT2=11;
reg [4:0] state = INIT1;
reg init;
reg [7:0] initctr;
assign ready=~init;


// BlockRAM and related signals for data

wire [10:0] data_port1_addr;
wire [10:0] data_port2_addr;
wire [17:0] data_port1_r;
wire [17:0] data_port2_r;
reg[17:0] data_ports_w;
reg data_wren1;
reg data_wren2;

Cache_DataRAM dataram(
	.clock(clk),
	.address_a(data_port1_addr),
	.address_b(data_port2_addr),
	.data_a(data_ports_w),
	.data_b(data_ports_w),
	.q_a(data_port1_r),
	.q_b(data_port2_r),
	.wren_a(data_wren1),
	.wren_b(data_wren2)
);

wire data_valid1;
wire data_valid2;

assign data_valid1 = data_port1_r[17] & data_port1_r[16];
assign data_valid2 = data_port2_r[17] & data_port2_r[16];

// BlockRAM and related signals for tags.

wire [8:0] tag_port1_addr;
wire [8:0] tag_port2_addr;
wire [17:0] tag_port1_r;
wire [17:0] tag_port2_r;
wire [17:0] tag_port1_w;
wire [17:0] tag_port2_w;

reg tag_wren1;
reg tag_wren2;
reg tag_mru1;

CacheBlockRAM tagram(
	.clock(clk),
	.address_a(tag_port1_addr),
	.address_b(tag_port2_addr),
	.data_a(tag_port1_w),
	.data_b(tag_port2_w),
	.q_a(tag_port1_r),
	.q_b(tag_port2_r),
	.wren_a(tag_wren1),
	.wren_b(tag_wren2)
);

//   bits 2:1 specify which word of a burst we're interested in.
//   Bits 10:3 specify the six bit address of the cachelines;
//   Since we're building a 2-way cache, we'll map this to 
//   {1'b0,addr[10:3]} and {1;b1,addr[10:3]} respectively.

wire [10:0] cacheline1;
wire [10:0] cacheline2;

reg readword_burst; // Set to 1 when the lsb of the cache address should
							// track the SDRAM controller.
reg [1:0] readword;

assign cacheline1 = {1'b0,cpu_addr[10:3],(readword_burst ? readword : cpu_addr[2:1])};
assign cacheline2 = {1'b1,cpu_addr[10:3],(readword_burst ? readword : cpu_addr[2:1])};

// We share each tag between all four words of a cacheline.  We therefore only need
// one M9K tag RAM for four M9Ks of data RAM.

assign tag_port1_addr = cacheline1[10:2];
assign tag_port2_addr = cacheline2[10:2];

// The first port contains the mru flag, so we have to write to it on every
// access.  The second tag only needs writing when a cacheline in the second
// block is updated, so we tie the write port of the second tag to part of the
// CPU address.
// The first port has to be toggled between old and new data, depending upon
// the state of the mru flag.
// (Writing both ports on every access for troubleshooting)

assign tag_port1_w = {tag_mru1,(tag_mru1 ? cpu_addr[25:9] : tag_port1_r[16:0])};
assign tag_port2_w = {1'b0,(!tag_mru1 ? cpu_addr[25:9] : tag_port2_r[16:0])};
//assign tag_port2_w = {1'b0,cpu_addr[25:9]};


// Boolean signals to indicate cache hits.

wire tag_hit1;
wire tag_hit2;

assign tag_hit1 = tag_port1_r[16:0]==cpu_addr[25:9];
assign tag_hit2 = tag_port2_r[16:0]==cpu_addr[25:9];


// In the data blockram the lower two bits of the address determine
// which word of the burst we're reading.  When reading from the cache, this comes
// from the CPU address; when writing to the cache it's determined by the state
// machine.


assign data_port1_addr = init ? {1'b0,initctr} : cacheline1;
assign data_port2_addr = init ? {1'b1,initctr} : cacheline2;


always @(posedge clk)
begin

	// Defaults
	tag_wren1<=1'b0;
	tag_wren2<=1'b0;
	data_wren1<=1'b0;
	data_wren2<=1'b0;
	cpu_ack<=1'b0;
	init<=1'b0;
	readword_burst<=1'b0;

	case(state)

		// FIXME - need an init state here that loops through the data clearing
		// the valid flag - for which we'll use bit 17 of the data entry.
	
		INIT1:
		begin
			init<=1'b1;	// need to mark the entire cache as invalid before starting.
			initctr<=8'b0000_0000;
			data_ports_w<=18'b0; // Mark entire cache as invalid
			data_wren1<=1'b1;
			data_wren2<=1'b1;
			state<=INIT2;
		end
		
		INIT2:
		begin
			init<=1'b1;
			initctr<=initctr+1;
			data_wren1<=1'b1;
			data_wren2<=1'b1;
			if(initctr==8'b1111_1111)
				state<=WAITING;
		end

		WAITING:
		begin
			state<=WAITING;
			if(cpu_req==1'b1)
			begin
				if(cpu_rw==1'b1)	// Read cycle
					state<=WAITRD;
				else	// Write cycle
					state<=WRITE1;
			end
		end
		WRITE1:
			begin
				// If the current address is in cache,
				// we must update the appropriate cacheline

				// FIXME - this won't work for byte accesses!
				
				// We mark the two halves of the word separately.
				// If this is a byte write, the byte not being written
				// will be marked as invalid, triggering a re-read if
				// the other byte or whole word is read.
				data_ports_w<={~cpu_rwu,~cpu_rwl,data_from_cpu};

 				if(tag_hit1)
				begin
					// Write the data to the first cache way
					data_wren1<=1'b1;
					// Mark tag1 as most recently used.
					tag_mru1<=1'b1;
					tag_wren1<=1'b1;
				end
				// Note: it's possible that both ways of the cache will end up caching
				// the same address; if so, we must write to both ways, or at least
				// invalidate them both, otherwise we'll have problems with stale data.
				if(tag_hit2)
				begin
					// Write the data to the second cache way
					data_wren2<=1'b1;
					// Mark tag2 as most recently used.
					tag_mru1<=1'b0;
					tag_wren1<=1'b1;
				end
				
				// FIXME - ultimately we should clear a cacheline here and cache
				// the data for future use.

				// FIXME - we also need to check at this point whether the write cache
				// can merge this data into the current write, and if so send an ack.

				state<=WRITE2;
			end

		WRITE2:
			begin
				if(cpu_req==1'b0)	// Wait for the write cycle to finish
					state<=WAITING;
			end

		WAITRD:
			begin
				state<=PAUSE1;
				// Check both tags for a match...
				if(tag_hit1 && data_valid1)
				begin
					// Copy data to output
					data_to_cpu<=data_port1_r;
					cpu_ack<=1'b1;

					// Mark tag1 as most recently used.
					tag_mru1<=1'b1;
					tag_wren1<=1'b1;
				end
				else if(tag_hit2 && data_valid2)
				begin
					// Copy data to output
					data_to_cpu<=data_port2_r;
					cpu_ack<=1'b1;
					
					// Mark tag2 as most recently used.
					tag_mru1<=1'b0;
					tag_wren1<=1'b1;
				end
				else	// No matches?  How do we decide which one to use?
				begin
					// invert most recently used flags on both tags.
					// (Whichever one was least recently used will be overwritten, so
					// is now the most recently used.)
					// If either tag matches, but the corresponding data is stale,
					// we re-use the stale cacheline.

					if(tag_hit1)
						tag_mru1<=1'b1;	// Way 1 contains stale data
					else if(tag_hit2)
						tag_mru1<=1'b0;	// Way 2 contains stale data
					else
						tag_mru1<=!tag_port1_r[17];

//					For simulation only, to avoid the unknown value of unitialised blockram
//					tag_mru1<=cpu_addr[1];

					tag_wren1<=1'b1;
					tag_wren2<=1'b1;
					// If r[17] is 1, tag_mru1 is 0, so we need to write to the second tag.
					// FIXME - might be simpler to just write every cycle and switch between new and old data.
//					tag_wren2<=tag_port1_r[17];

					// Pass request on to RAM controller.
					sdram_addr<={cpu_addr[31:3],3'b000};
					sdram_req<=1'b1;
					sdram_rw<=1'b1;	// Read cycle
					state<=WAITFILL;
				end
			end

		PAUSE1:
		begin
			state<=WAITING;
		end
		
		WAITFILL:
		begin
			readword_burst<=1'b1;
			// In the interests of performance, read the word we're waiting for first.
			readword<=cpu_addr[2:1];

			if (sdram_fill==1'b1)
			begin
				sdram_req<=1'b0;
				// Forward data to CPU
				data_to_cpu<=data_from_sdram;
				cpu_ack<=1'b1;

				// write first word to Cache...
				data_ports_w<={2'b11,data_from_sdram};
				data_wren1<=tag_mru1;
				data_wren2<=!tag_mru1;
				state<=FILL2;
			end
		end

		FILL2:
		begin
			// write second word to Cache...
			readword_burst<=1'b1;
			readword<=readword+1;
			data_ports_w<={2'b11,data_from_sdram};
			data_wren1<=tag_mru1;
			data_wren2<=!tag_mru1;
			state<=FILL3;
		end

		FILL3:
		begin
			// write third word to Cache...
			readword_burst<=1'b1;
			readword<=readword+1;
			data_ports_w<={2'b11,data_from_sdram};
			data_wren1<=tag_mru1;
			data_wren2<=!tag_mru1;
			state<=FILL4;
		end

		FILL4:
		begin
			// write last word to Cache...
			readword_burst<=1'b1;
			readword<=readword+1;
			data_ports_w<={2'b11,data_from_sdram};
			data_wren1<=tag_mru1;
			data_wren2<=!tag_mru1;
			state<=FILL5;
		end
		
		FILL5:
		begin
			readword=cpu_addr[2:1];
			state<=WAITING;
		end

		default:
			state<=WAITING;
	endcase
	
	if(reset==1'b0)
		state<=INIT1;
end


// Write cache:

parameter WC_WAITWRITE=0, WC_FILL=1, WV_FINISH=2;
reg[2:0] writecache_state;
reg[31:0] writecache_addr;
reg[15:0] writecache_word0;
reg[15:0] writecache_word1;
reg[15:0] writecache_word2;
reg[15:0] writecache_word3;
reg [7:0] writecache_dqm;

reg writecache_dirty;
reg writecache_ack;

//signal writecache_req : std_logic;
//signal writecache_dirty : std_logic;
//signal writecache_dtack : std_logic;
//signal writecache_burst : std_logic;
//
//	if reset='0' then
//		writecache_req<='0';
//		writecache_dirty<='0';
//		writecache_dqm<="11111111";
//		writecache_state<=waitwrite;
//	elsif rising_edge(sysclk) then
//
//		writecache_dtack<='1';
//		case writecache_state is
//			when waitwrite =>
//				if req1='1' and wr1='0' then -- write request
//					if writecache_dirty='0' or addr1(31 downto 3)=writecache_addr(31 downto 3) then
//						writecache_addr(31 downto 3)<=addr1(31 downto 3);
//						case addr1(2 downto 1) is
//							when "00" =>
//								writecache_word0<=datawr1;
//								writecache_dqm(1 downto 0)<=wrU1&wrL1;
//							when "01" =>
//								writecache_word1<=datawr1;
//								writecache_dqm(3 downto 2)<=wrU1&wrL1;
//							when "10" =>
//								writecache_word2<=datawr1;
//								writecache_dqm(5 downto 4)<=wrU1&wrL1;
//							when "11" =>
//								writecache_word3<=datawr1;
//								writecache_dqm(7 downto 6)<=wrU1&wrL1;
//						end case;
//						writecache_req<='1';
//
//						writecache_dtack<='0';
//						writecache_dirty<='1';
//					end if;
//				end if;
//				if writecache_burst='1' and writecache_dirty='1' then
//					writecache_req<='0';
//					writecache_state<=fill;
//				end if;
//			when fill =>
//				if writecache_burst='0' then
//					writecache_dirty<='0';
//					writecache_dqm<="11111111";
//					writecache_state<=waitwrite;
//				end if;
//			when others =>
//				null;
//		end case;
//				
//	end if;

endmodule
