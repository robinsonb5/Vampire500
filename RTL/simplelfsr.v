// Simple 22-bit LFSR, used for the SDRAM test project.
// ToDo: Genericise for other bit lengths.

module simplelfsr
(
	input clk,
	input reset, // Active high
	input ena,
	output reg [21:0] lfsr
);

// x^22 + x^21 + 1
always @(posedge clk)
begin
	if(reset)
		lfsr<=4;	// Chosen by fair dice roll.
					// Guaranteed to be random. </obligatory XKCD reference>
	else if(ena)
		lfsr<={lfsr[20:0],lfsr[21] ^ lfsr[20]};
end

endmodule
