module uart_controller (
    input  wire         clk,
    input  wire         rst,
    input  wire         rx,
    output wire         tx,
    output wire         led1,

    // RFID
    input  wire [31:0]  UID,
    input  wire         card_OK,

    // IR Sensors
    input  wire [4:0]   ir_status,

    // Dispenser Control Outputs
    input  wire         dispensing_active,
    output wire [4:0]   dispenser_start,
    output wire [3:0]   count_A, count_B, count_C, count_D, count_E
);

    // --- RX Signals ---
    wire [7:0]  rx_data_raw;
    wire        rx_valid_raw;
    wire [7:0]  rx_fifo_dout;
    wire        rx_fifo_empty;
    wire        rx_fifo_rd;

    // --- TX Signals ---
    wire [7:0]  tx_fifo_din;
    wire        tx_fifo_full;
    wire        tx_wr_en;
    wire [7:0]  tx_fifo_dout;
    wire        tx_fifo_empty;   
    wire        tx_ready;

    // FSM State Registers
    reg [1:0] current_state, next_state;
    reg        tx_fifo_rd;    // TX FIFO read enable
    reg        tx_data_valid; // UART TX data valid signal

    // --- TX Handshake Control Logic ---
    localparam IDLE       = 2'b00;
    localparam FETCH_FIFO = 2'b01;
    localparam SEND_UART  = 2'b10;
    localparam WAIT_ACK   = 2'b11; 
	

    // State Machine for TX Control
    always @(posedge clk) begin
        if (rst)    current_state <= IDLE;
        else        current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (!tx_fifo_empty && tx_ready) next_state = FETCH_FIFO;
            end

            FETCH_FIFO: begin
                next_state = SEND_UART;
            end

            SEND_UART: begin
                next_state = WAIT_ACK;
            end

            WAIT_ACK: begin
                if (!tx_ready) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk) begin
        if (rst) begin
            tx_fifo_rd     <= 1'b0;
            tx_data_valid  <= 1'b0;
        end else begin
            tx_fifo_rd     <= 1'b0;
            tx_data_valid  <= 1'b0;

            case (next_state)
                FETCH_FIFO: begin
                    tx_fifo_rd    <= 1'b1; 
                end

                SEND_UART: begin
                    tx_data_valid <= 1'b1; 
                end
            endcase
        end
    end

    // --- Physical Layer: UART RX ---
    uart_rx u_rx (
        .clk        (clk), 
        .rst        (rst), 
        .rx         (rx),
        .data_out   (rx_data_raw), 
        .data_valid (rx_valid_raw)
    );

    // --- Buffer: RX FIFO ---
    fifo_sync rx_fifo (
        .clk        (clk), 
        .rst        (rst),
        .wr_en      (rx_valid_raw), 
        .din        (rx_data_raw),
        .rd_en      (rx_fifo_rd), 
        .dout       (rx_fifo_dout), 
        .empty      (rx_fifo_empty),
        .full       () 
    );

    // --- Logic: Protocol Handler ---
    protocol_handler handler (
        .clk        (clk), 
        .rst        (rst),
        .rx_rd      (rx_fifo_rd), 
        .rx_empty   (rx_fifo_empty), 
        .rx_data    (rx_fifo_dout),
        .tx_wr      (tx_wr_en), 
        .tx_full    (tx_fifo_full), 
        .tx_data    (tx_fifo_din),
        .led1       (led1), 
        
        // RFID Interface
        .card_OK    (card_OK),
        .UID        (UID),
        
        // IR Sensors
        .input_ir   (ir_status),

        // Dispenser Interface
        .dispensing_active      (dispensing_active),
        .dispenser_start        (dispenser_start),
        .count_A                (count_A),
        .count_B                (count_B),
        .count_C                (count_C),
        .count_D                (count_D),
        .count_E                (count_E)
    );

    // --- Buffer: TX FIFO ---
    fifo_sync tx_fifo (
        .clk        (clk), 
        .rst        (rst),
        .wr_en      (tx_wr_en), 
        .din        (tx_fifo_din),
        .rd_en      (tx_fifo_rd), 
        .dout       (tx_fifo_dout), 
        .empty      (tx_fifo_empty),
        .full       (tx_fifo_full)
    );

    // --- Physical Layer: UART TX ---
    uart_tx u_tx (
        .clk        (clk), 
        .rst        (rst),
        .data_in    (tx_fifo_dout), 
        .data_valid (tx_data_valid),
        .tx         (tx), 
        .tx_ready   (tx_ready)
    );

endmodule