//============================================================================
// 버튼 디바운스 + 원펄스(엣지 검출) 모듈
// N비트 카운터 기반 디바운스 (약 10ms @ 100MHz, N=20)
//============================================================================
module debounce #(
    parameter N = 20  // 2^20 / 100MHz ≈ 10ms
)(
    input  clk,
    input  rst,
    input  btn_in,
    output btn_out,
    output btn_pulse   // Rising edge one-shot
);

    reg [N-1:0] cnt;
    reg         btn_state;
    reg         btn_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt       <= 0;
            btn_state <= 0;
            btn_prev  <= 0;
        end else begin
            btn_prev <= btn_state;
            if (btn_in != btn_state) begin
                cnt <= cnt + 1;
                if (cnt == {N{1'b1}})  // 카운터 최대값 도달
                    btn_state <= btn_in;
            end else begin
                cnt <= 0;
            end
        end
    end

    assign btn_out   = btn_state;
    assign btn_pulse = btn_state & ~btn_prev;  // Rising edge

endmodule
