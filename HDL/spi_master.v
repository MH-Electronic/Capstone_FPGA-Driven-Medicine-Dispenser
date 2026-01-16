module spi_master #(
    parameter DATA_WIDTH = 16,     // Configurable word length
    parameter CLK_DIV    = 32,     // 125MHz / 32 = 3.9MHz
    parameter CPOL       = 0,      // Clock Polarity (0: idle low, 1: idle high)
    parameter CPHA       = 0,      // Clock Phase (0: sample leading, 1: sample trailing)
    parameter LSB_FIRST  = 0,       // Bit Order (0: MSB first, 1: LSB first)

    // Timing Parameters
    parameter LEAD_TICKS = 15,
    parameter LAG_TICKS  = 15
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,
    input  wire [DATA_WIDTH-1:0]  tx_data,
    output reg  [DATA_WIDTH-1:0]  rx_data,
    output reg                    busy,

    output reg                    sclk,
    output reg                    mosi,
    input  wire                   miso,
    output reg                    cs_n
);

    // Dynamic counter widths
    reg [$clog2(CLK_DIV)-1:0]   clk_cnt;
    reg [$clog2(DATA_WIDTH):0]  bit_cnt;
    reg [DATA_WIDTH-1:0]        shift_reg;
    reg [1:0]                   miso_sync; 

    // States
    localparam IDLE     = 2'b00;
    localparam LEAD_IN  = 2'b01;
    localparam TRANSFER = 2'b10;
    localparam DONE     = 2'b11;

    reg [1:0] state;

    always @(posedge clk) miso_sync <= {miso_sync[0], miso};

    wire sample_edge = (CPHA == 0); 

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            sclk      <= CPOL;
            cs_n      <= 1;
            mosi      <= 0;
            rx_data   <= 0;
            bit_cnt   <= 0;
            clk_cnt   <= 0;
            shift_reg <= 0;
            busy      <= 0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n    <= 1;
                    sclk    <= CPOL;
                    busy    <= 0;
                    clk_cnt <= 0;
                    if (start) begin
                        state     <= LEAD_IN;
                        shift_reg <= tx_data;
                        busy      <= 1;
                    end
                end

                LEAD_IN: begin
                    cs_n    <= 0;
                    clk_cnt <= clk_cnt + 1;
                    mosi    <= LSB_FIRST ? shift_reg[0] : shift_reg[DATA_WIDTH-1];
                    if (clk_cnt == LEAD_TICKS) begin
                        state   <= TRANSFER;
                        bit_cnt <= DATA_WIDTH;
                        clk_cnt <= 0;
                    end
                end

                TRANSFER: begin
                    if (bit_cnt > 0) begin
                        clk_cnt <= clk_cnt + 1;

                        if (clk_cnt == CLK_DIV/2 - 1) begin
                            sclk <= ~sclk;
                            if (sample_edge) begin
                                shift_reg <= LSB_FIRST ? {miso_sync[1], shift_reg[DATA_WIDTH-1:1]} : {shift_reg[DATA_WIDTH-2:0], miso_sync[1]};
                            end else begin
                                mosi <= LSB_FIRST ? shift_reg[0] : shift_reg[DATA_WIDTH-1];
                            end
                        end 
                        else if (clk_cnt == CLK_DIV - 1) begin
                            sclk    <= ~sclk;
                            clk_cnt <= 0;
                            bit_cnt <= bit_cnt - 1;
                            
                            if (sample_edge) begin
                                if (bit_cnt > 1) 
                                    mosi <= LSB_FIRST ? shift_reg[0] : shift_reg[DATA_WIDTH-1];
                            end else begin
                                shift_reg <= LSB_FIRST ? {miso_sync[1], shift_reg[DATA_WIDTH-1:1]} : {shift_reg[DATA_WIDTH-2:0], miso_sync[1]};
                            end
                        end
                    end else begin
                        state   <= DONE;
                        clk_cnt <= 0;
                        rx_data <= shift_reg;
                    end
                end

                DONE: begin
                    clk_cnt <= clk_cnt + 1;
                    if (clk_cnt == LAG_TICKS) begin
                        cs_n    <= 1;
                        sclk    <= CPOL;
                        state   <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule