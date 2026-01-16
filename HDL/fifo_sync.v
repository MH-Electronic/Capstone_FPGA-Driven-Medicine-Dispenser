module fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  wire                  clk,
    input  wire                  rst,

    // Write interface
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,

    // Read interface
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire                  empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Memory and pointers
    reg [DATA_WIDTH-1:0]   mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0]   wr_ptr;
    reg [ADDR_WIDTH-1:0]   rd_ptr;
    reg [ADDR_WIDTH:0]     count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Write logic
    always @(posedge clk) begin
        if (rst)
            wr_ptr <= 0;
        else if (wr_en && !full) begin
            mem[wr_ptr]                 <= din;
            wr_ptr                      <= wr_ptr + 1'b1;
        end
    end

    // Read logic with 1-cycle latency data output
    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
            dout   <= 0;
        end else if (rd_en && !empty) begin
            dout   <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // Count logic
    always @(posedge clk) begin
        if (rst) count <= 0;
        else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1'b1;   // Write only
                2'b01: count <= count - 1'b1;   // Read only
                2'b11: count <= count;          // Simultaneous read and write
                default: count <= count;        // No change or simultaneous read/write
            endcase
        end
    end

endmodule