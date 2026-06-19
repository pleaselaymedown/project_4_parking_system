//============================================================================
// VGA 동기 신호 생성기
// 640x480 @ 60Hz, 25MHz 픽셀 클럭
// 100MHz 입력 클럭에서 pclk_en으로 25MHz 동작
//============================================================================
module vga_sync(
    input        clk,       // 100MHz
    input        rst,
    input        pclk_en,   // 25MHz pixel clock enable
    output reg   hsync,
    output reg   vsync,
    output       video_on,
    output reg [9:0] pixel_x,
    output reg [9:0] pixel_y
);

    // VGA 640x480 @ 60Hz 타이밍 파라미터
    // Horizontal
    localparam H_DISPLAY  = 640;
    localparam H_FRONT    = 16;
    localparam H_SYNC     = 96;
    localparam H_BACK     = 48;
    localparam H_TOTAL    = 800;

    // Vertical
    localparam V_DISPLAY  = 480;
    localparam V_FRONT    = 10;
    localparam V_SYNC     = 2;
    localparam V_BACK     = 33;
    localparam V_TOTAL    = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else if (pclk_en) begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    // 동기 신호 (active low)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hsync <= 1;
            vsync <= 1;
        end else if (pclk_en) begin
            hsync <= ~((h_cnt >= H_DISPLAY + H_FRONT) &&
                       (h_cnt <  H_DISPLAY + H_FRONT + H_SYNC));
            vsync <= ~((v_cnt >= V_DISPLAY + V_FRONT) &&
                       (v_cnt <  V_DISPLAY + V_FRONT + V_SYNC));
        end
    end

    // 픽셀 좌표 (표시 영역 내)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_x <= 0;
            pixel_y <= 0;
        end else if (pclk_en) begin
            pixel_x <= h_cnt;
            pixel_y <= v_cnt;
        end
    end

    assign video_on = (h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY);

endmodule
