# CMN_TESTING — Cable Test Application

## Project overview
Qt 6.8 / QML desktop app (Windows) for automated cable harness testing.
- Module URI: `CMN_TESTING`
- Build: CMake 3.16+, `qt_add_executable` + `qt_add_qml_module`

## Key components

### Hardware
- **MCU (Bộ chuyển mạch)**: relay matrix controller, USB-UART, context property `mcuSender` (class `McuSender`)
- **Keithley 2110-220 DMM**: measures resistance via USB virtual COM (USBTMC), SCPI protocol, 115200 8N1, context property `hiokiRM3544` (class `Keithley2110` — file `Keithley2110.h/.cpp`)

### C++ backend files
| File | Class | Context property |
|------|-------|-----------------|
| `McuSender.cpp/.h` | `McuSender` | `mcuSender` |
| `Keithley2110.cpp/.h` | `Keithley2110` | `keithley2110` |
| `CableListManager.cpp/.h` | `CableListManager` | `cableListManager` |
| `TestPlanManager.cpp/.h` | `TestPlanManager` | `testPlanManager` |
| `FileHelper.cpp/.h` | `FileHelper` | `fileHelper` |

### Power switching backend (separate subsystem)
`AppController`, `MrSeriesController`, `MdlSeriesController`, `ControllerBox`, `SignalMeasure`

### QML files
- `Main.qml` — root window
- `MainContent.qml` — main test results view
- `AutoTestWindow.qml` — automated test execution engine
- `AutoTestPlanDialog.qml` — test plan editor + Excel import
- `ManualTestView.qml` — manual step-by-step testing
- `ManualReadDialog.qml` — single manual resistance read
- `DeviceConfigDialog.qml` — COM port / device connection dialog
- `CalibrationDialog.qml`, `CableCalibrationDialog.qml` — calibration
- `CableListDialog.qml`, `TestPlanListDialog.qml` — list management

## Script types
| scriptType | MCU cmd | Pass condition | Device |
|-----------|---------|----------------|--------|
| `continuity` | `0x8F` | value ≤ limitUpper | Keithley 2110 |
| `sheath_insulation` | `0x8D` | value ≥ limitLower | Keithley 2110 |
| `notification` | — | always pass | — |

## MCU portByte values
- `0xAA` — both pins on MCU port A
- `0xBB` — both pins on MCU port B
- `0xAB` / `0xBA` — cross-port (pin A ↔ pin B)

For `sheath_insulation` (cmd `0x8D`): only `portPinA` is sent; ground is implicit.

## Excel test plan format (two sections)
- **Rows 2–62**: Continuity — col0=connectorA, col1=pinA_label, col2=portPinA, col3=connectorB, col4=pinB_label, col5=portPinB, col6=limitUpper (Ω, e.g. `≤0.8`)
- **Row 63**: Section header containing "Đo điện trở" → triggers `inSheathSection = true`
- **Rows 64+**: Sheath insulation — col0=connector, col1=pin_label, col2=portPinA, col6=limitLower (Ω, e.g. `≥100`)

## Keithley 2110 SCPI key commands
- `READ?\r\n` — trigger + read resistance
- `CONF:RES` — configure 2-wire resistance mode
- `SENS:RES:RANG <Ω>` — set range (100 / 1000 / 10000 / 100000 / 1000000 / 10000000)
- `SENS:RES:NPLC <n>` — integration time (FAST=0.1, MED=1, SLOW=10, SLOW2=100)
- OL (overload) response: `+9.90000000E+37`

## Third-party
- `third_party/QXlsx` — Excel `.xlsx` reading (optional; `HAVE_QXLSX` define)
