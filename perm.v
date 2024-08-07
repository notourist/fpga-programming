module ascon_p(
    input   [7:0] c_r,
    input  [63:0] x0_in,
    input  [63:0] x1_in,
    input  [63:0] x2_in,
    input  [63:0] x3_in,
    input  [63:0] x4_in,
    output [63:0] x0_out,
    output [63:0] x1_out,
    output [63:0] x2_out,
    output [63:0] x3_out,
    output [63:0] x4_out
);
    wire [63:0] t0_0, t1_0, t2_0, t3_0, t4_0;
    wire [63:0] t0_1, t1_1, t2_1, t3_1, t4_1;
    wire [63:0] t0_2, t1_2, t2_2, t3_2, t4_2;
    wire [63:0] t0_3, t1_3, t2_3, t3_3, t4_3;
    wire [63:0] t0_4, t1_4, t2_4, t3_4, t4_4;

    // Substitution layer
    assign t0_0 = x0_in ^ x4_in;
    assign t1_0 = x1_in;
    assign t2_0 = (x2_in ^ c_r) ^ x1_in; // Add constant
    assign t3_0 = x3_in;
    assign t4_0 = x4_in ^ x3_in;

    assign t0_1 = ~t0_0;
    assign t1_1 = ~t1_0;
    assign t2_1 = ~t2_0;
    assign t3_1 = ~t3_0;
    assign t4_1 = ~t4_0;

    assign t0_2 = t0_1 & t1_0;
    assign t1_2 = t1_1 & t2_0;
    assign t2_2 = t2_1 & t3_0;
    assign t3_2 = t3_1 & t4_0;
    assign t4_2 = t4_1 & t0_0;

    assign t0_3 = t0_0 ^ t1_2;
    assign t1_3 = t1_0 ^ t2_2;
    assign t2_3 = t2_0 ^ t3_2;
    assign t3_3 = t3_0 ^ t4_2;
    assign t4_3 = t4_0 ^ t0_2;

    assign t0_4 = t0_3 ^ t4_3;
    assign t1_4 = t1_3 ^ t0_3;
    assign t2_4 = ~t2_3;
    assign t3_4 = t3_3 ^ t2_3;
    assign t4_4 = t4_3;
    
    wire [63:0] x0, x1, x2, x3, x4;
    assign x0 = t0_4;
    assign x1 = t1_4;
    assign x2 = t2_4;
    assign x3 = t3_4;
    assign x4 = t4_4;

    // Diffusion layer
    assign x0_out = x0 ^ {x0[18:0], x0[63:19]} ^ {x0[27:0], x0[63:28]};
    assign x1_out = x1 ^ {x1[60:0], x1[63:61]} ^ {x1[38:0], x1[63:39]};
    assign x2_out = x2 ^ {x2[0], x2[63:1]} ^ {x2[5:0], x2[63:6]};
    assign x3_out = x3 ^ {x3[9:0], x3[63:10]} ^ {x3[16:0], x3[63:17]};
    assign x4_out = x4 ^ {x4[6:0], x4[63:7]} ^ {x4[40:0], x4[63:41]};
endmodule
