# 🅿️ Project_4 Parking System 🅿️
<br>

## 📌 1. Project Summary (프로젝트 요약)

Basys3 FPGA 보드에서 Verilog RTL 설계로 구현한 **초음파 센서 기반 스마트 주차장 관리 시스템**입니다.

차량번호를 입력해 입차/출차를 처리하고, 빈 주차 공간을 자동으로 배정하며, 초음파 센서를 통해 실제 차량 주차 여부를 확인합니다. VGA 화면에는 주차장 전체 상태를 시각적으로 출력하고, 7-Segment에는 차량번호, 배정 위치, 오류 메시지 등을 표시합니다.

<br>


## ✨ 2. Key Features (주요 기능)

### 2.1 Entry / Exit Mode Control (입차·출차 모드 제어)

- `sw[0]` 스위치로 입차 모드와 출차 모드를 선택
- `btnC` 버튼으로 입차/출차 동작 시작 및 입력 확정
- 차량번호 입력 후 입차 시 빈자리 자동 배정, 출차 시 등록된 차량번호 검색 후 자리 해제

### 2.2  Car Number Input (차량번호 입력)

- 4자리 차량번호를 7-Segment로 표시
- `btnU`, `btnD`로 숫자 증가/감소
- `btnL`, `btnR`로 입력 자릿수 이동
- 현재 입력 중인 자릿수는 깜빡임으로 표시

### 2.3  Random Parking Spot Assignment (랜덤 주차 자리 배정)

- 총 16개의 주차 공간을 관리
- LFSR 기반의 랜덤 시작점을 이용해 빈 주차 공간 탐색
- 입차 차량번호가 기존 등록 번호와 중복되면 `Err` 출력
- 주차장이 가득 찬 경우 `FULL` 출력

### 2.4  Ultrasonic Sensor Parking Check (초음파 센서 기반 주차 확인)

- HC-SR04 초음파 센서를 사용해 차량 감지
- 1m 이내 물체가 5초 이상 연속 감지되면 해당 공간을 `PARKED` 상태로 전환
- 입차 직후에는 `ASSIGNED` 상태로 관리하고, 실제 감지 후 주차 완료 처리

### 2.5 VGA Parking Display (VGA 주차장 화면 출력)

- VGA 640x480 해상도로 주차장 상태 표시
- 4개 층, 각 층 4개 자리 구조로 총 16개 공간 표현
- 빈자리/배정된 자리: 초록색 점
- 주차 완료 자리: 빨간색 점
- 남은 자리가 2개 이하일 때 초록색 점 깜빡임으로 경고 표시

### 2.6  FSM-based State Management (상태 머신 기반 제어)

- `IDLE`, `INPUT`, `DONE`, `SHOW_MSG` 상태로 시스템 흐름 관리
- 입차, 출차, 만차, 오류 상황을 FSM으로 분리해 제어
- 버튼 입력, 차량번호 검색, 자리 배정, 메시지 출력 흐름을 명확하게 구성
<br>


## ⚙️ 3. Tech Stack (기술 스택)

### 3.1 Language (사용 언어)

![Verilog](https://img.shields.io/badge/Verilog-HDL-blue?style=for-the-badge)

### 3.2 Development Environment (개발 환경)

![Vivado](https://img.shields.io/badge/AMD%20Vivado-F6A800?style=for-the-badge)
![VSCode](https://img.shields.io/badge/VS%20Code-007ACC?style=for-the-badge)


<br>

## 📂 4. Project Structure (프로젝트 구조)

### Project Tree (프로젝트 트리)

```text
parking_system/
├── parking_system.xpr                         # Vivado 프로젝트 파일
├── parking_system.srcs/
│   ├── sources_1/
│   │   └── imports/parking_system/
│   │       ├── parking_system_top.v            # 최상위 모듈
│   │       ├── parking_controller.v            # 주차장 제어 FSM
│   │       ├── ultrasonic_sensor.v             # HC-SR04 초음파 센서 제어
│   │       ├── vga_sync.v                      # VGA 동기 신호 생성
│   │       ├── vga_parking_display.v           # VGA 주차장 화면 출력
│   │       ├── seg7_controller.v               # 7-Segment 표시 제어
│   │       ├── debounce.v                      # 버튼 디바운스 및 원펄스 처리
│   │       └── parking_system_tb.v             # 시뮬레이션 테스트벤치
│   │
│   └── constrs_1/
│       └── imports/parking_system/
│           └── parking_system.xdc              # Basys3 핀 제약 조건
│
├── parking_system.sim/                         # Vivado 시뮬레이션 결과
├── parking_system.runs/                        # 합성/구현/비트스트림 결과
└── README.md                                   # 프로젝트 설명 문서
```
---
<br>

## 🧩 5. System Design (시스템 설계)

### 5.1 Hardware Block Diagram (하드웨어 블록다이어그램)

```mermaid
flowchart LR
    CLK[100MHz Clock] --> TOP[parking_system_top]

    BTN[Buttons\nbtnC / btnU / btnD / btnL / btnR] --> DB[debounce]
    DB --> CTRL[parking_controller]

    SW[Switches\nsw0: Entry/Exit\nsw1: Reset] --> TOP
    TOP --> CTRL

    US[HC-SR04 Ultrasonic Sensor] --> ULTRA[ultrasonic_sensor]
    ULTRA --> CTRL

    CTRL --> SEG[seg7_controller]
    SEG --> SEGOUT[7-Segment Display]

    TOP --> VSYNC[vga_sync]
    VSYNC --> VGA[vga_parking_display]
    CTRL --> VGA
    VGA --> MONITOR[VGA Monitor]
```

### 5.2 System Flow Chart (동작 흐름도)

```mermaid
flowchart TD
    A[IDLE] --> B{btnC 입력?}
    B -- No --> A
    B -- Yes --> C{모드 선택}

    C -- 입차 모드 --> D{주차장 만차?}
    D -- Yes --> E[FULL 표시]
    D -- No --> F[차량번호 입력]

    F --> G{차량번호 중복?}
    G -- Yes --> H[Err 표시]
    G -- No --> I[랜덤 빈자리 배정]
    I --> J[7-Segment에 배정 위치 표시]
    J --> K{초음파 1m 이내 5초 감지?}
    K -- Yes --> L[PARKED 상태 전환]
    K -- No --> K

    C -- 출차 모드 --> M[차량번호 입력]
    M --> N{등록된 차량번호?}
    N -- Yes --> O[주차 자리 해제]
    N -- No --> H

    E --> A
    H --> A
    L --> A
    O --> A
```

---

## 6. I/O Control (입출력 제어)

| Input / Output | Function |
|---|---|
| `sw[0]` | 입차/출차 모드 선택, `0`: 입차, `1`: 출차 |
| `sw[1]` | 시스템 리셋 |
| `btnC` | 시작 및 확인 |
| `btnU` | 현재 자릿수 숫자 증가 |
| `btnD` | 현재 자릿수 숫자 감소 |
| `btnL` | 입력 위치 왼쪽 이동 |
| `btnR` | 입력 위치 오른쪽 이동 |
| `ultra_trig` | 초음파 센서 Trigger 출력 |
| `ultra_echo` | 초음파 센서 Echo 입력 |
| `vga_r/g/b`, `vga_hs`, `vga_vs` | VGA 화면 출력 |
| `seg`, `an`, `dp` | 7-Segment 출력 |

---

## 🎬 7. Demonstration (시연 영상)

<br><br>

<p> <a href="https://www.youtube.com/watch?v=hIA0RXWNTHo"> <img src="./images/youtube.png" alt="YouTube Demo" width="500"> </a> </p>

### *이미지를 클릭하면 영상으로 이동합니다*

<br><br>


## 🎯 8. Troubleshooting (문제 해결 기록)

### 8.1 빈자리 표시 문제

**🔍 문제 상황**

- 주차 공간이 얼마 없는 상황일 때, 화면에서 빈자리를 한 눈에 찾기 어려움

**❓ 원인 분석**

- 빈자리가 많을 때는 상관없지만, 빈자리가 줄어들수록 수가 적어져 눈에 띄기 힘들다

**❗ 해결 방법**

- 남은 빈자리가 2개 이하일 때 초록색 점이 깜빡이도록 로직을 추가

**✅ 결과**

- 주차 공간이 얼마 남지 않았을 때, VGA 화면에서 확인하기 용이하게 됨
---

### 8.2 주차 위치 확인 문제

**🔍 문제 상황**

- 차량이 입차 처리된 직후 바로 주차 완료 상태로 표시하면 어디에 차량이 주차했는지 확인하기 어려움

**❓ 원인 분석**

- 시각적으로 진행상황을 확인할 수 있는 단계가 필요

**❗ 해결 방법**

- 차량이 초음파 센서에 감지됐을 때, VGA화면에 3초간 깜빡이는 로직을 넣음

**✅ 결과**

- 차량이 주차 완료되었을 때 해당 자리에 3초간 점으로 깜빡이면서 표시되어, 주차된 위치를 쉽게 확인할 수 있음

---

### 8.3 주차 완료 상태 전환 오류

**🔍 문제 상황**

- 입차시 차량 번호를 입력한 후 초음파 센서에 감지되지 않았는데 해당 자리에 즉시 주차 완료로 표시되는 문제

**❓ 원인 분석**

- FSM(유한 상태 머신)을 확인한 결과, 입차 확인 시 ‘주차 완료’상태로 즉시 전환됨을 확인
- 
**❗ 해결 방법**

-  → 중간 단계에 ‘배정됨’ 상태를 추가하여 로직을 변경
-  
**✅ 결과**

- 차량 번호 입력 직후에는 해당 자리가 주차 완료가 아닌 배정 상태로 표시되도록 함
- 초음파 센서가 실제 차량을 감지한 경우에만 주차 완료 상태로 변경되어, VGA 화면의 주차 상태 표시를 정확하게 나타낼 수 있게됨

<br>

---

## 🔧 9. Future Improvements (개선 사항)

- Basys3 내부 클럭으로 각 자리별 주차 시간을 카운팅하고, 출차 시 경과 시간에 따라 요금을 7-seg에 표시하는 기능을 추가
- UART, Bluetooth, Wi-Fi 등을 이용해 PC 또는 모바일 화면에서 주차 상태 확인
- VGA 화면에 남은 자리 수, 차량번호 일부, 입차/출차 모드 등을 추가 표시


