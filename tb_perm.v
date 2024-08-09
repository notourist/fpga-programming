`include "perm.v"
`timescale 100ms / 1ms

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module tb_perm();
    wire [63:0] x0, x1, x2, x3, x4;
    wire [7:0] c_r;
    assign x4 = 64'h0;
    assign x1 = 64'h0;
    assign x2 = 64'h0;
    assign x3 = 64'h0;
    assign x0 = 64'h80400c0600000000;
    assign c_r = 'hf0;

    wire [63:0] x0_out, x1_out, x2_out, x3_out, x4_out;

    ascon_p perm(c_r, x0, x1, x2, x3, x4, x0_out, x1_out, x2_out, x3_out, x4_out);

    initial begin
        #1
        $display("c_r: %x\n", c_r);
        $display("%x\n%x\n%x\n%x\n%x\n", x0, x1, x2, x3, x4);
        $display("\n\n");
        $display("%x\n%x\n%x\n%x\n%x\n", x0_out, x1_out, x2_out, x3_out, x4_out);
        `assert(x0_out, 64'h3c1748c9be2892ce)
    end
endmodule
