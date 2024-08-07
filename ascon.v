module ascon(
        input          clk,
        input          rst,
        input          mode,
        // We cannot use the full 64 bits, because we want to use
        // the GPIO pins and only have 64. We need to fit
        // the data and control signals into those,
        // => 32 bits + control bits < 64 bits
        input wire [31:0] key,
        input wire [31:0] key_valid,
        output wire       key_ready,
        input wire [31:0] nonce,
        input wire        nonce_valid,
        output wire       nonce_ready,
        input wire [31:0] data_in,
        input wire  [3:0] data_in_type,
        input wire        data_in_valid,
        input wire        data_in_last,
        output reg        data_in_ready,
        output reg [31:0] data_out,        
        // We also need to tell the user which type the output data
        // is, because it can be either ciphertext + tag or plaintext + tag
        output reg  [3:0] data_out_type,
        output reg        data_out_valid,
        output reg        data_out_last
    );
    // mode
    localparam MODE_DEC = 0;
    localparam MODE_ENC = 1;

    // data types
    localparam TYPE_EMPTY  = 4'h0;
    localparam TYPE_ASSOC  = 4'h1;
    localparam TYPE_PLAIN  = 4'h2;
    localparam TYPE_CIPHER = 4'h3;
    localparam TYPE_TAG    = 4'h4;

    // ascon parameters
    // a = 12
    // b = 6
    // k = 128
    // r = 64
    localparam ROUNDS_A = 12;
    localparam ROUNDS_B = 6;
    localparam KEY_LENGTH = 128;
    localparam DATA_LENGTH = 64;
    localparam IV = 320'h80400c0600000000 << 192;
    
    // state machine
    localparam STATE_WAIT          = 0;
    localparam STATE_READ_KEY      = 1;
    localparam STATE_READ_NONCE    = 2;
    localparam STATE_DO_INIT       = 3;
    localparam STATE_PROCESS_ASSOC = 4;
    localparam STATE_PROCESS_PLAIN = 5;
    localparam STATE_FINAL         = 6;

    reg [3:0] state_machine;
    reg [3:0] next_state;

    reg [319:0] ascon_state;
    reg [127:0] ascon_key;

    initial begin
        state_machine <= STATE_WAIT;
    end

    // state machine transitions
    always @(posedge clk)
    begin
        case (state_machine)
            STATE_WAIT: next_state <= STATE_READ_KEY;

            default: ;
        endcase
    end

    // ascon state updates
    always @(posedge clk)
    begin
        case (state_machine)
            STATE_WAIT: 
            begin
                next_state <= STATE_READ_KEY;
            end
            default: ;
        endcase
    end

    // output updates
    always @(posedge clk)
    begin
        data_in_ready = 0;
        data_out = 32'b0;
        data_out_type = TYPE_EMPTY;
        data_out_valid = 0;
        data_out_last = 0;
        case (state_machine)
            STATE_WAIT: ;
            default: ;
        endcase
    end

    // reset
    always @(posedge clk)
    begin
        if (rst)
        begin
            state_machine <= STATE_WAIT;
        end else begin
            state_machine <= next_state;
        end
    end
endmodule
