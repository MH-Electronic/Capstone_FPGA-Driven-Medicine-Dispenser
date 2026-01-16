module uart_tx #(
    parameter integer CLOCK_FREQ = 125_000_000,
    parameter integer BAUD_RATE  = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,
    input  wire       data_valid,
    output reg        tx,
    output reg        tx_ready
);
    localparam integer TICKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    
    // States
    localparam IDLE     = 1'b0;
    localparam ACTIVE   = 1'b1;

    reg         current_state, next_state;
    reg [31:0]  tick_cnt;
    reg [3:0]   bit_cnt;     // 10 bits: 1 start, 8 data, 1 stop
    reg [9:0]   tx_frame;
    wire        bit_done;

    // State Machine
    always @(posedge clk) begin
        if (rst)    current_state <= IDLE;
        else        current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE:   if (data_valid) next_state = ACTIVE;
            ACTIVE: if (bit_done)   next_state = (bit_cnt == 9) ? IDLE : ACTIVE;
        endcase
    end

    // Output Logic
    always @(posedge clk) begin
        if (rst) begin
            tx         <= 1'b1;
            tx_ready   <= 1'b1;
        end else begin
            case (current_state)
                IDLE: begin
                    tx       <= 1'b1; // Idle state is high
                    tx_ready <= 1'b1;
                    if (data_valid) begin
                        // Load frame: start bit (0), data bits, stop bit (1)
                        tx_frame <= {1'b1, data_in, 1'b0};
                        tx       <= 1'b0; 
                        bit_cnt  <= 0;
                        tick_cnt <= 0;
                        tx_ready <= 1'b0;
                    end
                end

                ACTIVE: begin
                    if (bit_done) begin
                        tick_cnt <= 0;
                        if (bit_cnt == 9) begin
                            tx      <= 1'b1; 
                        end else begin
                            tx      <= tx_frame[bit_cnt + 1];
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        tick_cnt    <= tick_cnt + 1;
                    end
                end
            endcase
        end
    end

    assign bit_done = (tick_cnt == TICKS_PER_BIT - 1);

endmodule