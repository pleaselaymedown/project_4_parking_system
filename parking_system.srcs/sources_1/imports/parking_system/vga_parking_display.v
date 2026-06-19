//============================================================================
// VGA 주차장 화면 생성 모듈 (v3)
// - 빈자리(EMPTY) + 배정됨(ASSIGNED): 초록색 점 (고정)
//   → 빈자리 ≤2개 남으면 깜빡이는 초록색
// - 주차됨(PARKED): 빨간색 점 (고정)
//============================================================================
module vga_parking_display(
    input        clk,
    input        pclk_en,
    input        video_on,
    input  [9:0] pixel_x,
    input  [9:0] pixel_y,
    input [31:0] spot_status_flat,
    input  [4:0] empty_count,
    input        blink_clk,
    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b
);

    // =========================================================
    // 상수
    // =========================================================
    localparam SPOT_EMPTY    = 2'd0;
    localparam SPOT_ASSIGNED = 2'd1;
    localparam SPOT_PARKED   = 2'd2;

    // 10% 임계값: ceil(16 * 0.1) = 2
    localparam FEW_THRESHOLD = 5'd2;
    wire few_spots_left = (empty_count <= FEW_THRESHOLD) && (empty_count > 0);

    // 레이아웃 상수
    localparam COL_W     = 160;
    localparam RECT_X0   = 15;
    localparam RECT_X1   = 145;
    localparam RECT_Y0   = 80;
    localparam RECT_Y1   = 420;
    localparam CROSS_Y   = 250;
    localparam CROSS_X   = 80;
    localparam DOT_R     = 8;
    localparam BORDER_W  = 2;

    // 각 자리 점 중심 (열 내 오프셋)
    localparam SPOT_X0 = (RECT_X0 + CROSS_X) / 2;
    localparam SPOT_Y0 = (RECT_Y0 + CROSS_Y) / 2;
    localparam SPOT_X1 = (CROSS_X + RECT_X1) / 2;
    localparam SPOT_Y1 = (RECT_Y0 + CROSS_Y) / 2;
    localparam SPOT_X2 = (RECT_X0 + CROSS_X) / 2;
    localparam SPOT_Y2 = (CROSS_Y + RECT_Y1) / 2;
    localparam SPOT_X3 = (CROSS_X + RECT_X1) / 2;
    localparam SPOT_Y3 = (CROSS_Y + RECT_Y1) / 2;

    // =========================================================
    // 폰트 ROM (8x12 비트맵) - 1, 2, 3, 4, F
    // =========================================================
    reg [7:0] font_1 [0:11];
    reg [7:0] font_2 [0:11];
    reg [7:0] font_3 [0:11];
    reg [7:0] font_4 [0:11];
    reg [7:0] font_F [0:11];

    initial begin
        font_1[0]  = 8'b00010000; font_1[1]  = 8'b00110000;
        font_1[2]  = 8'b01110000; font_1[3]  = 8'b00110000;
        font_1[4]  = 8'b00110000; font_1[5]  = 8'b00110000;
        font_1[6]  = 8'b00110000; font_1[7]  = 8'b00110000;
        font_1[8]  = 8'b00110000; font_1[9]  = 8'b00110000;
        font_1[10] = 8'b01111100; font_1[11] = 8'b00000000;

        font_2[0]  = 8'b01111100; font_2[1]  = 8'b11000110;
        font_2[2]  = 8'b00000110; font_2[3]  = 8'b00000110;
        font_2[4]  = 8'b00001100; font_2[5]  = 8'b00011000;
        font_2[6]  = 8'b00110000; font_2[7]  = 8'b01100000;
        font_2[8]  = 8'b11000000; font_2[9]  = 8'b11000110;
        font_2[10] = 8'b11111110; font_2[11] = 8'b00000000;

        font_3[0]  = 8'b01111100; font_3[1]  = 8'b11000110;
        font_3[2]  = 8'b00000110; font_3[3]  = 8'b00000110;
        font_3[4]  = 8'b00111100; font_3[5]  = 8'b00000110;
        font_3[6]  = 8'b00000110; font_3[7]  = 8'b00000110;
        font_3[8]  = 8'b00000110; font_3[9]  = 8'b11000110;
        font_3[10] = 8'b01111100; font_3[11] = 8'b00000000;

        font_4[0]  = 8'b00001100; font_4[1]  = 8'b00011100;
        font_4[2]  = 8'b00111100; font_4[3]  = 8'b01101100;
        font_4[4]  = 8'b11001100; font_4[5]  = 8'b11111110;
        font_4[6]  = 8'b00001100; font_4[7]  = 8'b00001100;
        font_4[8]  = 8'b00001100; font_4[9]  = 8'b00001100;
        font_4[10] = 8'b00011110; font_4[11] = 8'b00000000;

        font_F[0]  = 8'b11111110; font_F[1]  = 8'b11000000;
        font_F[2]  = 8'b11000000; font_F[3]  = 8'b11000000;
        font_F[4]  = 8'b11111100; font_F[5]  = 8'b11000000;
        font_F[6]  = 8'b11000000; font_F[7]  = 8'b11000000;
        font_F[8]  = 8'b11000000; font_F[9]  = 8'b11000000;
        font_F[10] = 8'b11000000; font_F[11] = 8'b00000000;
    end

    // =========================================================
    // 열(층) 및 열 내 오프셋
    // =========================================================
    wire [1:0] col_idx = (pixel_x < 160) ? 2'd0 :
                         (pixel_x < 320) ? 2'd1 :
                         (pixel_x < 480) ? 2'd2 : 2'd3;

    wire [9:0] col_base = (col_idx == 2'd0) ? 10'd0   :
                          (col_idx == 2'd1) ? 10'd160 :
                          (col_idx == 2'd2) ? 10'd320 : 10'd480;

    wire [7:0] x_in_col = pixel_x - col_base;

    // =========================================================
    // 경계선/테두리/십자선
    // =========================================================
    wire is_col_border = (pixel_x == 0) || (pixel_x == 159) ||
                         (pixel_x == 160) || (pixel_x == 319) ||
                         (pixel_x == 320) || (pixel_x == 479) ||
                         (pixel_x == 480) || (pixel_x == 639);

    wire in_rect_area = (x_in_col >= RECT_X0) && (x_in_col <= RECT_X1) &&
                        (pixel_y >= RECT_Y0) && (pixel_y <= RECT_Y1);

    wire is_rect_border = in_rect_area && (
        (x_in_col <= RECT_X0 + BORDER_W - 1) ||
        (x_in_col >= RECT_X1 - BORDER_W + 1) ||
        (pixel_y  <= RECT_Y0 + BORDER_W - 1) ||
        (pixel_y  >= RECT_Y1 - BORDER_W + 1)
    );

    wire is_cross_h = in_rect_area &&
                      (pixel_y >= CROSS_Y - 1) && (pixel_y <= CROSS_Y);
    wire is_cross_v = in_rect_area &&
                      (x_in_col >= CROSS_X - 1) && (x_in_col <= CROSS_X);

    // =========================================================
    // 층수 텍스트 ("1F"~"4F") - 노란색, 2배 확대
    // =========================================================
    localparam TEXT_X0    = 20;
    localparam TEXT_Y0    = 20;
    localparam TEXT_SCALE = 2;

    wire in_digit_area = (x_in_col >= TEXT_X0) &&
                         (x_in_col < TEXT_X0 + 8 * TEXT_SCALE) &&
                         (pixel_y >= TEXT_Y0) &&
                         (pixel_y < TEXT_Y0 + 12 * TEXT_SCALE);

    wire in_f_area = (x_in_col >= TEXT_X0 + 8 * TEXT_SCALE + 2) &&
                     (x_in_col < TEXT_X0 + 16 * TEXT_SCALE + 2) &&
                     (pixel_y >= TEXT_Y0) &&
                     (pixel_y < TEXT_Y0 + 12 * TEXT_SCALE);

    wire [3:0] font_row_d = (pixel_y - TEXT_Y0) / TEXT_SCALE;
    wire [2:0] font_col_d = (x_in_col - TEXT_X0) / TEXT_SCALE;
    wire [3:0] font_row_f = (pixel_y - TEXT_Y0) / TEXT_SCALE;
    wire [2:0] font_col_f = (x_in_col - TEXT_X0 - 8 * TEXT_SCALE - 2) / TEXT_SCALE;

    reg is_digit_pixel, is_f_pixel;
    always @(*) begin
        is_digit_pixel = 0;
        if (in_digit_area) begin
            case (col_idx)
                2'd0: is_digit_pixel = font_1[font_row_d][7 - font_col_d];
                2'd1: is_digit_pixel = font_2[font_row_d][7 - font_col_d];
                2'd2: is_digit_pixel = font_3[font_row_d][7 - font_col_d];
                2'd3: is_digit_pixel = font_4[font_row_d][7 - font_col_d];
            endcase
        end
        is_f_pixel = 0;
        if (in_f_area)
            is_f_pixel = font_F[font_row_f][7 - font_col_f];
    end

    wire is_text_pixel = is_digit_pixel || is_f_pixel;

    // =========================================================
    // 각 자리 상태 추출
    // =========================================================
    reg [1:0] s0_status, s1_status, s2_status, s3_status;
    always @(*) begin
        case (col_idx)
            2'd0: begin
                s0_status = spot_status_flat[1:0];
                s1_status = spot_status_flat[3:2];
                s2_status = spot_status_flat[5:4];
                s3_status = spot_status_flat[7:6];
            end
            2'd1: begin
                s0_status = spot_status_flat[9:8];
                s1_status = spot_status_flat[11:10];
                s2_status = spot_status_flat[13:12];
                s3_status = spot_status_flat[15:14];
            end
            2'd2: begin
                s0_status = spot_status_flat[17:16];
                s1_status = spot_status_flat[19:18];
                s2_status = spot_status_flat[21:20];
                s3_status = spot_status_flat[23:22];
            end
            2'd3: begin
                s0_status = spot_status_flat[25:24];
                s1_status = spot_status_flat[27:26];
                s2_status = spot_status_flat[29:28];
                s3_status = spot_status_flat[31:30];
            end
        endcase
    end

    // =========================================================
    // 점 영역 검출
    // =========================================================
    wire in_dot0 = (x_in_col >= SPOT_X0 - DOT_R) && (x_in_col <= SPOT_X0 + DOT_R) &&
                   (pixel_y  >= SPOT_Y0 - DOT_R) && (pixel_y  <= SPOT_Y0 + DOT_R);
    wire in_dot1 = (x_in_col >= SPOT_X1 - DOT_R) && (x_in_col <= SPOT_X1 + DOT_R) &&
                   (pixel_y  >= SPOT_Y1 - DOT_R) && (pixel_y  <= SPOT_Y1 + DOT_R);
    wire in_dot2 = (x_in_col >= SPOT_X2 - DOT_R) && (x_in_col <= SPOT_X2 + DOT_R) &&
                   (pixel_y  >= SPOT_Y2 - DOT_R) && (pixel_y  <= SPOT_Y2 + DOT_R);
    wire in_dot3 = (x_in_col >= SPOT_X3 - DOT_R) && (x_in_col <= SPOT_X3 + DOT_R) &&
                   (pixel_y  >= SPOT_Y3 - DOT_R) && (pixel_y  <= SPOT_Y3 + DOT_R);

    // =========================================================
    // 점 색상 결정
    // PARKED       → 빨간색 (고정)
    // EMPTY/ASSIGNED → 초록색 (고정, 빈자리 ≤2이면 깜빡임)
    // =========================================================
    reg       show_dot;
    reg [3:0] dot_r, dot_g, dot_b;

    always @(*) begin
        show_dot = 0;
        dot_r = 0; dot_g = 0; dot_b = 0;

        // Spot 0
        if (in_dot0) begin
            if (s0_status == SPOT_PARKED) begin
                show_dot = 1;
                dot_r = 4'hF; dot_g = 4'h0; dot_b = 4'h0;
            end else begin
                // EMPTY 또는 ASSIGNED → 초록
                if (few_spots_left) begin
                    show_dot = blink_clk;
                end else begin
                    show_dot = 1;
                end
                dot_r = 4'h0; dot_g = 4'hF; dot_b = 4'h0;
            end
        end

        // Spot 1
        if (in_dot1 && !show_dot) begin
            if (s1_status == SPOT_PARKED) begin
                show_dot = 1;
                dot_r = 4'hF; dot_g = 4'h0; dot_b = 4'h0;
            end else begin
                if (few_spots_left) begin
                    show_dot = blink_clk;
                end else begin
                    show_dot = 1;
                end
                dot_r = 4'h0; dot_g = 4'hF; dot_b = 4'h0;
            end
        end

        // Spot 2
        if (in_dot2 && !show_dot) begin
            if (s2_status == SPOT_PARKED) begin
                show_dot = 1;
                dot_r = 4'hF; dot_g = 4'h0; dot_b = 4'h0;
            end else begin
                if (few_spots_left) begin
                    show_dot = blink_clk;
                end else begin
                    show_dot = 1;
                end
                dot_r = 4'h0; dot_g = 4'hF; dot_b = 4'h0;
            end
        end

        // Spot 3
        if (in_dot3 && !show_dot) begin
            if (s3_status == SPOT_PARKED) begin
                show_dot = 1;
                dot_r = 4'hF; dot_g = 4'h0; dot_b = 4'h0;
            end else begin
                if (few_spots_left) begin
                    show_dot = blink_clk;
                end else begin
                    show_dot = 1;
                end
                dot_r = 4'h0; dot_g = 4'hF; dot_b = 4'h0;
            end
        end
    end

    // =========================================================
    // 최종 픽셀 색상
    // =========================================================
    always @(posedge clk) begin
        if (!video_on) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else if (show_dot) begin
            vga_r <= dot_r;
            vga_g <= dot_g;
            vga_b <= dot_b;
        end else if (is_text_pixel) begin
            vga_r <= 4'hF;
            vga_g <= 4'hF;
            vga_b <= 4'h0;
        end else if (is_rect_border || is_cross_h || is_cross_v) begin
            vga_r <= 4'hF;
            vga_g <= 4'hF;
            vga_b <= 4'hF;
        end else if (is_col_border) begin
            vga_r <= 4'h5;
            vga_g <= 4'h5;
            vga_b <= 4'h5;
        end else begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h2;
        end
    end

endmodule