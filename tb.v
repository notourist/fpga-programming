`timescale 100ms / 1ms

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end

module tb_perm();
    wire [63:0] x0, x1, x2, x3, x4;
    wire [7:0] c_r;
    assign x0 = 64'h0123456789abcdef;
    assign x1 = 64'h23456789abcdef01;
    assign x2 = 64'h456789abcdef0123;
    assign x3 = 64'h6789abcdef012345;
    assign x4 = 64'h89abcde01234567f;
    assign c_r = 'h1f;

    wire [63:0] x0_out, x1_out, x2_out, x3_out, x4_out;

    ascon_p perm(c_r, x0, x1, x2, x3, x4, x0_out, x1_out, x2_out, x3_out, x4_out);

    initial begin
        #1
        `assert(x0_out, 64'h3c1748c9be2892ce)
    end
endmodule

module tb_ascon();
endmodule
