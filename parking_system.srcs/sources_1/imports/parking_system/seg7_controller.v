//============================================================================
// 7-Segment 디스플레이 컨트롤러
// - 4자리 멀티플렉싱 (시분할)
// - BCD 0~9 디코딩
// - 특수 문자 표시: FULL, Err
// - 자릿수 깜빡임 기능
//============================================================================
module seg7_controller(
    input        clk,
    input        rst,
    input  [3:0] digit0,        // 맨 왼쪽 (AN3)
    input  [3:0] digit1,        // (AN2)
    input  [3:0] digit2,        // (AN1)
    input  [3:0] digit3,        // 맨 오른쪽 (AN0)
    input  [3:0] blink_mask,    // 깜빡일 자릿수 {d0,d1,d2,d3}
    input        blink_clk,     // 깜빡임 클럭
    input        show_special,  // 특수 문자 모드
    input  [1:0] special_code,  // 0=none, 1=FULL, 2=Err
    output reg [6:0] seg,       // {CA,CB,CC,CD,CE,CF,CG} active low
    output reg       dp,        // 소수점 (active low)
    output reg [3:0] an         // 애노드 (active low)
);

    // =========================================================
    // 멀티플렉싱 카운터 (~1kHz 리프레시)
    // =========================================================
    reg [16:0] refresh_cnt;
    wire [1:0] digit_sel = refresh_cnt[16:15]; // 00~11 순환

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_cnt <= 0;
        else
            refresh_cnt <= refresh_cnt + 1;
    end

    // =========================================================
    // 현재 표시할 자릿수 선택
    // =========================================================
    reg [3:0] current_digit;
    reg       current_blink;

    // 특수 문자용 세그먼트 패턴
    // FULL: F-U-L-L
    // Err:  E-r-r-(blank)
    reg [6:0] special_seg;

    always @(*) begin
        // 기본값
        current_digit = 4'd0;
        current_blink = 0;
        special_seg   = 7'b1111111; // blank

        if (show_special) begin
            case (special_code)
                2'd1: begin // "FULL"
                    case (digit_sel)
                        2'd3: special_seg = 7'b0111000; // F: a,e,f,g
                        2'd2: special_seg = 7'b1000001; // U: b,c,d,e,f
                        2'd1: special_seg = 7'b1110001; // L: d,e,f
                        2'd0: special_seg = 7'b1110001; // L: d,e,f
                    endcase
                end
                2'd2: begin // "Err "
                    case (digit_sel)
                        2'd3: special_seg = 7'b0110000; // E: a,d,e,f,g
                        2'd2: special_seg = 7'b1111010; // r: e,g
                        2'd1: special_seg = 7'b1111010; // r: e,g
                        2'd0: special_seg = 7'b1111111; // blank
                    endcase
                end
                default: special_seg = 7'b1111111;
            endcase
        end else begin
            case (digit_sel)
                2'd3: begin current_digit = digit0; current_blink = blink_mask[3]; end
                2'd2: begin current_digit = digit1; current_blink = blink_mask[2]; end
                2'd1: begin current_digit = digit2; current_blink = blink_mask[1]; end
                2'd0: begin current_digit = digit3; current_blink = blink_mask[0]; end
            endcase
        end
    end

    // =========================================================
    // BCD to 7-Segment 디코딩 (active low)
    // {CA,CB,CC,CD,CE,CF,CG}
    // =========================================================
    reg [6:0] seg_pattern;

    always @(*) begin
        case (current_digit)
            4'd0: seg_pattern = 7'b0000001;
            4'd1: seg_pattern = 7'b1001111;
            4'd2: seg_pattern = 7'b0010010;
            4'd3: seg_pattern = 7'b0000110;
            4'd4: seg_pattern = 7'b1001100;
            4'd5: seg_pattern = 7'b0100100;
            4'd6: seg_pattern = 7'b0100000;
            4'd7: seg_pattern = 7'b0001111;
            4'd8: seg_pattern = 7'b0000000;
            4'd9: seg_pattern = 7'b0000100;
            4'hA: seg_pattern = 7'b0001000; // A
            4'hB: seg_pattern = 7'b1100000; // b
            4'hC: seg_pattern = 7'b0110001; // C
            4'hD: seg_pattern = 7'b1000010; // d
            4'hE: seg_pattern = 7'b0110000; // E (층-자리 구분자로 사용)
            4'hF: seg_pattern = 7'b1111111; // blank
            default: seg_pattern = 7'b1111111;
        endcase
    end

    // =========================================================
    // 출력
    // =========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seg <= 7'b1111111;
            dp  <= 1'b1;
            an  <= 4'b1111;
        end else begin
            // 애노드 선택
            case (digit_sel)
                2'd3: an <= 4'b0111; // AN3 (맨 왼쪽)
                2'd2: an <= 4'b1011; // AN2
                2'd1: an <= 4'b1101; // AN1
                2'd0: an <= 4'b1110; // AN0 (맨 오른쪽)
            endcase

            // 세그먼트 출력
            if (show_special) begin
                seg <= special_seg;
            end else begin
                // 깜빡임 처리
                if (current_blink && !blink_clk)
                    seg <= 7'b1111111; // 꺼짐 (깜빡임)
                else
                    seg <= seg_pattern;
            end

            dp <= 1'b1; // 소수점 항상 꺼짐
        end
    end

endmodule
