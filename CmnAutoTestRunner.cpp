#include "CmnAutoTestRunner.h"
#include "MrSeriesController.h"
#include "MdlSeriesController.h"
#include "ControllerBox.h"
#include "SignalMeasure.h"
#include "McuSender.h"

#include <QTimer>
#include <QVariantMap>
#include <QtMath>
#include <QSettings>
#include <QFileInfo>
#include <QDir>

#ifdef HAVE_QXLSX
#include "xlsxdocument.h"
#endif

// ── Static data ──────────────────────────────────────────────────────────────

const QStringList CmnAutoTestRunner::kAllRelayNames = {
    "VLS_ON","Bat1_ON","VLS_BatON","VLS_BatOFF",
    "MPSS_TBKT","CMD_ERM","CMD_PUMP","CCBH_in",
    "CMD_PPA","CMD_Pyro1","CMD_Pyro2","CMD_TJE",
    "CMD_FUZE"
};


// ── Constructor ──────────────────────────────────────────────────────────────

CmnAutoTestRunner::CmnAutoTestRunner(MrSeriesController  *mr,
                                     MdlSeriesController *mdl,
                                     ControllerBox       *box,
                                     SignalMeasure       *sig,
                                     McuSender           *mcu,
                                     QObject *parent)
    : QObject(parent), m_mr(mr), m_mdl(mdl), m_box(box), m_sig(sig), m_mcu(mcu)
{
    m_stepTimer = new QTimer(this);
    m_stepTimer->setSingleShot(true);
    connect(m_stepTimer, &QTimer::timeout, this, &CmnAutoTestRunner::executeNextStep);

    if (m_mcu) {
        connect(m_mcu, &McuSender::mcuRelayAck, this, &CmnAutoTestRunner::onRelayAck);
        connect(m_mcu, &McuSender::mcuRelayNak, this, &CmnAutoTestRunner::onRelayNak);
    }

    // Khôi phục cài đặt từ lần dùng trước
    QSettings s("CMN_TESTING", "AutoRunner");
    m_defaultSaveDir = s.value("defaultSaveDir").toString();
    QString lastPath  = s.value("lastExcelPath").toString();
    QString lastSheet = s.value("lastSheetName").toString();
    if (!lastPath.isEmpty() && QFileInfo::exists(lastPath)) {
        if (loadExcel(lastPath) && !lastSheet.isEmpty())
            selectSheet(lastSheet);
    }
}

// ── Properties ───────────────────────────────────────────────────────────────

QString CmnAutoTestRunner::currentType() const
{
    if (m_currentStep >= 0 && m_currentStep < m_steps.size())
        return m_steps[m_currentStep].type;
    return {};
}

QString CmnAutoTestRunner::currentDesc() const
{
    if (m_currentStep >= 0 && m_currentStep < m_steps.size())
        return m_steps[m_currentStep].desc;
    return {};
}

double CmnAutoTestRunner::failRate() const
{
    int total = m_okCount + m_ngCount;
    return total > 0 ? 100.0 * m_ngCount / total : 0.0;
}

// ── Excel loading ─────────────────────────────────────────────────────────────

bool CmnAutoTestRunner::loadExcel(const QString &filePath)
{
#ifdef HAVE_QXLSX
    QXlsx::Document xlsx(filePath);
    QStringList sheets = xlsx.sheetNames();
    if (sheets.isEmpty()) {
        emit logMessage("[AUTO] Lỗi: không đọc được file " + filePath);
        return false;
    }
    m_excelPath   = filePath;
    m_sheetNames  = sheets;
    QSettings("CMN_TESTING", "AutoRunner").setValue("lastExcelPath", filePath);
    emit sheetNamesChanged();
    emit logMessage("[AUTO] Đã load Excel: " + filePath + "  (" + QString::number(sheets.size()) + " sheets)");

    // Auto-select first sheet
    selectSheet(sheets.first());
    return true;
#else
    Q_UNUSED(filePath)
    emit logMessage("[AUTO] QXlsx không khả dụng — không thể đọc Excel");
    return false;
#endif
}

bool CmnAutoTestRunner::selectSheet(const QString &sheetName)
{
#ifdef HAVE_QXLSX
    if (m_excelPath.isEmpty()) return false;

    QXlsx::Document xlsx(m_excelPath);
    if (!xlsx.selectSheet(sheetName)) {
        emit logMessage("[AUTO] Không tìm thấy sheet: " + sheetName);
        return false;
    }

    m_selectedSheet = sheetName;
    QSettings("CMN_TESTING", "AutoRunner").setValue("lastSheetName", sheetName);
    m_steps.clear();
    m_stepResults.clear();
    m_okCount = 0;
    m_ngCount = 0;
    m_currentStep = 0;

    const int lastRow = xlsx.dimension().lastRow();
    for (int row = 3; row <= lastRow; ++row) {
        TestStep s;
        s.stt  = xlsx.read(row, 1).toInt();
        s.type = xlsx.read(row, 2).toString().trimmed();
        s.desc = xlsx.read(row, 3).toString().trimmed();
        s.p1   = xlsx.read(row, 4).toString().trimmed();
        s.p2   = xlsx.read(row, 5).toString().trimmed();
        s.p3   = xlsx.read(row, 6).toString().trimmed();
        s.req  = xlsx.read(row, 7).toString().trimmed();

        if (s.type.isEmpty() && s.desc.isEmpty()) continue;
        if (s.stt == 0 && s.type.isEmpty()) continue;

        m_steps.append(s);
        m_stepResults.append(stepToMap(m_steps.size() - 1));
    }

    emit totalStepsChanged();
    emit currentStepChanged();
    emit stepResultsChanged();
    emit statsChanged();
    emit logMessage("[AUTO] Sheet \"" + sheetName + "\": " + QString::number(m_steps.size()) + " bước");
    return true;
#else
    Q_UNUSED(sheetName)
    return false;
#endif
}

// ── Run control ───────────────────────────────────────────────────────────────

void CmnAutoTestRunner::runAll()
{
    if (m_steps.isEmpty()) {
        emit logMessage("[AUTO] Chưa load file Excel");
        return;
    }
    resetRunState();
    m_running = true;
    emit runningChanged();
    emit logMessage("[AUTO] ▶ Bắt đầu chạy — " + QString::number(m_steps.size()) + " bước");
    scheduleNext(0);
}

void CmnAutoTestRunner::pause()
{
    if (!m_running || m_paused) return;
    m_paused = true;
    m_stepTimer->stop();
    emit pausedChanged();
    emit logMessage("[AUTO] ⏸ Tạm dừng tại bước " + QString::number(m_currentStep + 1));
}

void CmnAutoTestRunner::resume()
{
    if (!m_running || !m_paused || m_waitingConfirm) return;
    m_paused = false;
    emit pausedChanged();
    emit logMessage("[AUTO] ▶ Tiếp tục");
    scheduleNext(0);
}

void CmnAutoTestRunner::stop()
{
    m_stepTimer->stop();
    m_running        = false;
    m_paused         = false;
    m_waitingConfirm = false;
    m_waitingRelay   = false;
    m_relayQueue.clear();
    m_relayQueueIdx  = 0;
    emit runningChanged();
    emit pausedChanged();
    emit waitingConfirmChanged();
    emit logMessage("[AUTO] ■ Đã dừng tại bước " + QString::number(m_currentStep + 1));
}

void CmnAutoTestRunner::confirmStep()
{
    if (!m_waitingConfirm) return;
    writeStepResult(m_currentStep, 0.0, true);
    m_waitingConfirm = false;
    emit waitingConfirmChanged();
    advanceStep();
}

// ── Main execution loop ───────────────────────────────────────────────────────

void CmnAutoTestRunner::executeNextStep()
{
    if (!m_running || m_paused || m_waitingConfirm || m_waitingRelay) return;

    if (m_currentStep >= m_steps.size()) {
        m_running = false;
        emit runningChanged();
        emit allDone(m_okCount, m_ngCount, failRate());
        emit logMessage(QString("[AUTO] ✓ Hoàn thành — ĐẠT: %1  KHÔNG ĐẠT: %2  Fail: %3%")
                        .arg(m_okCount).arg(m_ngCount).arg(failRate(), 0, 'f', 1));
        return;
    }

    const TestStep &step = m_steps[m_currentStep];
    emit stepStarted(m_currentStep, step.type, step.desc);
    emit currentStepChanged();

    const QString type = step.type.toUpper().trimmed();

    if (type == "ACTION") {
        const QString descLow = step.desc.toLower();

        // Steps requiring operator confirmation
        if (descLow.contains("kết nối") || descLow.contains("check_housing") ||
            descLow.contains("check_connector") || descLow.contains("packaging") ||
            descLow.contains("đóng gói"))
        {
            m_confirmMessage = step.desc;
            m_waitingConfirm = true;
            emit confirmMessageChanged();
            emit waitingConfirmChanged();
            emit stepNeedsConfirm(m_currentStep, step.desc);
            emit logMessage("[AUTO] ⏳ Chờ xác nhận: " + step.desc);
            return;
        }

        if (descLow.contains("set relay")) {
            flushRelayBuffer();
            emit logMessage("[AUTO] → Flush relay buffer");
        } else if (descLow.contains("nhấn set") && !descLow.contains("relay")) {
            flushLoadEnableBuffer();
            emit logMessage("[AUTO] → Flush load enable buffer");
        } else if (descLow.contains("start measure")) {
            if (m_sig) m_sig->startMeasure();
            emit logMessage("[AUTO] → Start measure");
        } else if (descLow.contains("vcm") || descLow.contains("listen")) {
            emit logMessage("[AUTO] → VCM action (bỏ qua): " + step.desc);
        } else if (descLow.contains("auto mode") || descLow.contains("chuyển sang")) {
            emit logMessage("[AUTO] → Mode switch action (bỏ qua): " + step.desc);
        } else {
            emit logMessage("[AUTO] → ACTION: " + step.desc);
        }

        writeStepResult(m_currentStep, 0.0, true);
        advanceStep();

    } else if (type == "SET_SOURCE") {
        if (!m_mr) { advanceStep(); return; }

        const QString param = step.p1.trimmed();
        const double  val   = step.p2.toDouble();

        bool ok = true;
        if (param.compare("Voltage", Qt::CaseInsensitive) == 0) {
            m_mr->setSetVoltage(val);
            m_mr->applyVoltage();
            emit logMessage(QString("[AUTO] SET_SOURCE Voltage = %1 V").arg(val));
        } else if (param.compare("Current_Max", Qt::CaseInsensitive) == 0) {
            m_mr->setSetCurrent(val);
            m_mr->applyCurrent();
            emit logMessage(QString("[AUTO] SET_SOURCE Current_Max = %1 A").arg(val));
        } else if (param.compare("Current_Protect", Qt::CaseInsensitive) == 0) {
            m_mr->setSetOCP(val);
            m_mr->applyOCP();
            emit logMessage(QString("[AUTO] SET_SOURCE Current_Protect = %1 A").arg(val));
        } else if (param.compare("Output_Enable", Qt::CaseInsensitive) == 0) {
            bool on = step.p2.trimmed().toUpper() == "ON";
            m_mr->setOutput(on);
            emit logMessage(QString("[AUTO] SET_SOURCE Output_Enable = %1").arg(on ? "ON" : "OFF"));
        } else {
            emit logMessage("[AUTO] SET_SOURCE param không rõ: " + param);
            ok = false;
        }
        // Ghi giá trị số thực vào result (Output_Enable dùng 1.0/0.0)
        double resultVal = val;
        if (param.compare("Output_Enable", Qt::CaseInsensitive) == 0)
            resultVal = (step.p2.trimmed().toUpper() == "ON") ? 1.0 : 0.0;
        writeStepResult(m_currentStep, resultVal, ok);
        advanceStep();

    } else if (type == "SET_RELAY") {
        const QString relayName = step.p1.trimmed();
        const bool    state     = step.p2.trimmed().toUpper() == "ON";

        if (relayName.toUpper() == "ALL") {
            for (const QString &r : kAllRelayNames)
                m_relayBuffer[r] = state;
            emit logMessage(QString("[AUTO] SET_RELAY ALL = %1 (buffered)").arg(state?"ON":"OFF"));
        } else if (relayName.toUpper() == "ALL_OTHERS") {
            for (const QString &r : kAllRelayNames)
                if (!m_mentionedRelays.contains(r))
                    m_relayBuffer[r] = false;
            emit logMessage("[AUTO] SET_RELAY ALL_OTHERS = OFF (buffered)");
        } else {
            m_relayBuffer[relayName] = state;
            if (!m_mentionedRelays.contains(relayName))
                m_mentionedRelays.append(relayName);
            emit logMessage(QString("[AUTO] SET_RELAY %1 = %2 (buffered)").arg(relayName, state?"ON":"OFF"));
        }
        writeStepResult(m_currentStep, 0.0, true);
        advanceStep();

    } else if (type == "SET_LOAD") {
        int ch = channelForLoad(step.p1);
        if (ch > 0 && m_mdl) {
            double curr = step.p3.toDouble();
            m_loadCurrentBuffer[step.p1] = curr;
            m_mdl->setChannelCurrent(ch, curr);
            emit logMessage(QString("[AUTO] SET_LOAD %1 (CH%2) source=%3 current=%4 A")
                            .arg(step.p1).arg(ch).arg(step.p2).arg(curr));
        }
        writeStepResult(m_currentStep, 0.0, true);
        advanceStep();

    } else if (type == "ENABLE_LOAD") {
        const bool on = step.p2.trimmed().toUpper() == "ON";
        m_loadEnableBuffer[step.p1] = on;
        emit logMessage(QString("[AUTO] ENABLE_LOAD %1 = %2 (buffered)").arg(step.p1, on?"ON":"OFF"));
        writeStepResult(m_currentStep, 0.0, true);
        advanceStep();

    } else if (type == "VERIFY") {
        double value = readSignalValue(step.p1);
        Requirement r = parseRequirement(step.req);
        bool pass = checkValue(value, r);
        writeStepResult(m_currentStep, value, pass);
        emit stepCompleted(m_currentStep, value, pass);
        emit logMessage(QString("[AUTO] VERIFY %1 = %2  (%3)")
                        .arg(step.p1).arg(value, 0, 'f', 3).arg(pass?"ĐẠT":"KHÔNG ĐẠT"));
        advanceStep();

    } else if (type == "RESULT_V") {
        int ch = channelForLoad(step.p1);
        double value = ch > 0 ? readLoadVoltage(ch) : 0.0;
        Requirement r = parseRequirement(step.req);
        bool pass = checkValue(value, r);
        writeStepResult(m_currentStep, value, pass);
        // Cache for SAISO
        m_resultCache[step.p1]["V_Load"] = value;
        emit stepCompleted(m_currentStep, value, pass);
        emit logMessage(QString("[AUTO] RESULT_V %1 CH%2 = %3 V  (%4)")
                        .arg(step.p1).arg(ch).arg(value, 0, 'f', 3).arg(pass?"ĐẠT":"KHÔNG ĐẠT"));
        advanceStep();

    } else if (type == "RESULT_I") {
        int ch = channelForLoad(step.p1);
        double value = ch > 0 ? readLoadCurrent(ch) : 0.0;
        double setpoint = m_loadCurrentBuffer.value(step.p1, 0.0);
        Requirement r = parseRequirement(step.req);
        bool pass = checkValue(value, r, setpoint);
        writeStepResult(m_currentStep, value, pass);
        m_resultCache[step.p1]["I_Load"] = value;
        emit stepCompleted(m_currentStep, value, pass);
        emit logMessage(QString("[AUTO] RESULT_I %1 CH%2 = %3 A  setpoint=%4  (%5)")
                        .arg(step.p1).arg(ch).arg(value, 0, 'f', 3).arg(setpoint, 0, 'f', 3).arg(pass?"ĐẠT":"KHÔNG ĐẠT"));
        advanceStep();

    } else if (type == "SAISO_V" || type == "SAISO_I") {
        // p1=loadName, p2=GS type (V_GS/I_GS), p3=ref (V_Load/I_Load or number)
        double gsVal  = m_resultCache.value(step.p1).value(step.p2, 0.0);
        double refVal = 0.0;
        bool   refOk  = false;
        bool   ok2    = false;
        refVal = step.p3.toDouble(&ok2);
        if (!ok2) {
            refVal = m_resultCache.value(step.p1).value(step.p3, 0.0);
            refOk  = (refVal != 0.0);
        } else {
            refOk = true;
        }
        double saiSo = (refOk && refVal != 0.0) ? qAbs(gsVal - refVal) / qAbs(refVal) * 100.0 : 0.0;
        Requirement r = parseRequirement(step.req);
        bool pass = checkValue(saiSo, r);
        writeStepResult(m_currentStep, saiSo, pass);
        emit stepCompleted(m_currentStep, saiSo, pass);
        emit logMessage(QString("[AUTO] %1 %2: GS=%3 ref=%4 saiSo=%5%  (%6)")
                        .arg(type, step.p1).arg(gsVal, 0, 'f', 3).arg(refVal, 0, 'f', 3)
                        .arg(saiSo, 0, 'f', 2).arg(pass?"ĐẠT":"KHÔNG ĐẠT"));
        advanceStep();

    } else if (type == "TEARDOWN") {
        executeTeardown(step.p1);

        const QString p1u = step.p1.toUpper();
        if (p1u == "CHECK_HOUSING" || p1u == "CHECK_CONNECTOR" || p1u == "PACKAGING") {
            m_confirmMessage = step.desc.isEmpty() ? step.p1 : step.desc;
            m_waitingConfirm = true;
            emit confirmMessageChanged();
            emit waitingConfirmChanged();
            emit stepNeedsConfirm(m_currentStep, m_confirmMessage);
            emit logMessage("[AUTO] ⏳ TEARDOWN chờ xác nhận: " + m_confirmMessage);
            return;
        }
        writeStepResult(m_currentStep, 0.0, true);
        advanceStep();

    } else {
        emit logMessage("[AUTO] Bỏ qua bước không rõ loại: " + step.type + " — " + step.desc);
        writeStepResult(m_currentStep, 0.0, true);
        advanceStep();
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void CmnAutoTestRunner::advanceStep()
{
    m_currentStep++;
    emit currentStepChanged();
    scheduleNext(80);
}

void CmnAutoTestRunner::scheduleNext(int delayMs)
{
    if (m_running && !m_paused && !m_waitingConfirm && !m_waitingRelay)
        m_stepTimer->start(delayMs);
}

void CmnAutoTestRunner::resetRunState()
{
    m_stepTimer->stop();
    m_currentStep    = 0;
    m_paused         = false;
    m_waitingConfirm = false;
    m_waitingRelay   = false;
    m_relayQueue.clear();
    m_relayQueueIdx  = 0;
    m_okCount        = 0;
    m_ngCount        = 0;
    m_relayBuffer.clear();
    m_mentionedRelays.clear();
    m_loadEnableBuffer.clear();
    m_loadCurrentBuffer.clear();
    m_resultCache.clear();

    // Reset step results
    m_stepResults.clear();
    for (int i = 0; i < m_steps.size(); ++i)
        m_stepResults.append(stepToMap(i));
    emit stepResultsChanged();
    emit statsChanged();
}

void CmnAutoTestRunner::flushRelayBuffer()
{
    // Build relay queue từ buffer
    m_relayQueue.clear();
    m_relayQueueIdx = 0;
    for (auto it = m_relayBuffer.constBegin(); it != m_relayBuffer.constEnd(); ++it) {
        const QString &name = it.key();
        bool state = it.value();
        int pin = m_mcu ? m_mcu->relayPin(name) : -1;
        if (pin < 0) {
            emit logMessage(QString("[AUTO] ⚠ Relay '%1' không có trong pin map — bỏ qua").arg(name));
            continue;
        }
        m_relayQueue.append({pin, state, name});
    }
    m_relayBuffer.clear();
    m_mentionedRelays.clear();

    if (m_relayQueue.isEmpty()) {
        emit logMessage("[AUTO] Relay buffer trống");
        return;
    }

    // Dùng McuSender nếu có, nếu không fallback về ControllerBox
    if (m_mcu && m_mcu->isOpen()) {
        m_waitingRelay = true;
        const auto &cmd = m_relayQueue[0];
        emit logMessage(QString("[AUTO] → Relay [1/%1] %2 (pin %3) = %4")
            .arg(m_relayQueue.size()).arg(cmd.name).arg(cmd.pin).arg(cmd.state ? "ON" : "OFF"));
        m_mcu->sendRelayByName(cmd.name, cmd.state);
    } else {
        // Fallback: ControllerBox JSON
        if (m_box) {
            for (const auto &cmd : m_relayQueue)
                m_box->setRelay(cmd.name, cmd.state);
        }
        emit logMessage(QString("[AUTO] Flush relay (fallback): %1 lệnh").arg(m_relayQueue.size()));
        m_relayQueue.clear();
    }
}

void CmnAutoTestRunner::onRelayAck()
{
    if (!m_waitingRelay) return;
    m_relayQueueIdx++;

    if (m_relayQueueIdx >= m_relayQueue.size()) {
        // Tất cả relay đã gửi xong
        m_waitingRelay = false;
        m_relayQueue.clear();
        emit logMessage("[AUTO] ✓ Flush relay hoàn thành");
        advanceStep();
        return;
    }

    // Gửi relay tiếp theo
    const auto &cmd = m_relayQueue[m_relayQueueIdx];
    emit logMessage(QString("[AUTO] → Relay [%1/%2] %3 (pin %4) = %5")
        .arg(m_relayQueueIdx + 1).arg(m_relayQueue.size())
        .arg(cmd.name).arg(cmd.pin).arg(cmd.state ? "ON" : "OFF"));
    m_mcu->sendRelayFrame(cmd.pin, cmd.state);
}

void CmnAutoTestRunner::onRelayNak(int errCode)
{
    if (!m_waitingRelay) return;
    const auto &cmd = m_relayQueue[m_relayQueueIdx];
    QString errStr;
    switch (errCode) {
    case 0x01: errStr = "CRC sai";     break;
    case 0x02: errStr = "Timeout";     break;
    case 0x03: errStr = "Hết retry";   break;
    case 0x04: errStr = "MCU bận";     break;
    default:   errStr = QString("0x%1").arg(errCode, 2, 16, QChar('0')).toUpper();
    }
    emit logMessage(QString("[AUTO] ✗ Relay '%1' NAK [%2] — bỏ qua, tiếp tục")
        .arg(cmd.name).arg(errStr));

    // Tiếp tục relay tiếp theo dù bị NAK
    m_relayQueueIdx++;
    if (m_relayQueueIdx >= m_relayQueue.size()) {
        m_waitingRelay = false;
        m_relayQueue.clear();
        emit logMessage("[AUTO] Flush relay xong (có lỗi NAK)");
        advanceStep();
        return;
    }
    const auto &next = m_relayQueue[m_relayQueueIdx];
    emit logMessage(QString("[AUTO] → Relay [%1/%2] %3 (pin %4) = %5")
        .arg(m_relayQueueIdx + 1).arg(m_relayQueue.size())
        .arg(next.name).arg(next.pin).arg(next.state ? "ON" : "OFF"));
    m_mcu->sendRelayFrame(next.pin, next.state);
}

void CmnAutoTestRunner::flushLoadEnableBuffer()
{
    if (!m_mdl) return;
    for (auto it = m_loadEnableBuffer.constBegin(); it != m_loadEnableBuffer.constEnd(); ++it) {
        int ch = channelForLoad(it.key());
        if (ch > 0) m_mdl->setChannelEnabled(ch, it.value());
    }
    emit logMessage(QString("[AUTO] Flush load enable: %1 kênh").arg(m_loadEnableBuffer.size()));
    m_loadEnableBuffer.clear();
}

void CmnAutoTestRunner::executeTeardown(const QString &p1)
{
    const QString p1u = p1.toUpper().trimmed();
    if (p1u == "ALL_RELAY") {
        if (m_box)
            for (const QString &r : kAllRelayNames)
                m_box->setRelay(r, false);
        emit logMessage("[AUTO] TEARDOWN: tắt tất cả relay");
    } else if (p1u == "ALL_LOADS") {
        if (m_mdl)
            for (int ch = 1; ch <= 6; ++ch)
                m_mdl->setChannelEnabled(ch, false);
        emit logMessage("[AUTO] TEARDOWN: tắt tất cả load");
    } else if (p1u == "DC_SOURCE") {
        if (m_mr) m_mr->setOutput(false);
        emit logMessage("[AUTO] TEARDOWN: tắt nguồn DC");
    }
}

void CmnAutoTestRunner::writeStepResult(int index, double value, bool pass)
{
    if (index < 0 || index >= m_steps.size()) return;
    TestStep &s = m_steps[index];
    s.resultValue = value;
    s.evaluation  = pass ? "ĐẠT" : "KHÔNG ĐẠT";
    s.hasResult   = true;

    if (pass) m_okCount++; else m_ngCount++;
    emit statsChanged();

    if (index < m_stepResults.size()) {
        m_stepResults[index] = stepToMap(index);
        emit stepResultsChanged();
    }
}

QVariantMap CmnAutoTestRunner::stepToMap(int index) const
{
    if (index < 0 || index >= m_steps.size()) return {};
    const TestStep &s = m_steps[index];

    // displayValue: chỉ dùng cho KẾT QUẢ — giá trị đo được kèm đơn vị.
    // ACTION/SET_RELAY/ENABLE_LOAD/TEARDOWN để trống (evaluation đã đủ).
    QString displayValue;
    const QString t = s.type.toUpper().trimmed();
    if (s.hasResult) {
        if (t == "VERIFY" || t == "RESULT_V" || t == "RESULT_I" ||
            t == "SAISO_V" || t == "SAISO_I") {
            displayValue = QString::number(s.resultValue, 'f', 3);
            if (!s.p3.isEmpty()) displayValue += " " + s.p3;
        } else if (t == "SET_SOURCE") {
            const QString p2u = s.p2.trimmed().toUpper();
            if (p2u == "ON" || p2u == "OFF") displayValue = p2u;
            else {
                displayValue = QString::number(s.resultValue, 'f', 3);
                if (!s.p3.isEmpty()) displayValue += " " + s.p3;
            }
        }
        // ACTION, SET_RELAY, ENABLE_LOAD, SET_LOAD, TEARDOWN: displayValue trống
    }

    // reqDisplay: ưu tiên req từ Excel; nếu trống thì tổng hợp từ p1/p2/p3
    QString reqDisplay = s.req;
    if (reqDisplay.isEmpty()) {
        if (t == "SET_SOURCE") {
            if (!s.p2.isEmpty() && !s.p3.isEmpty())
                reqDisplay = s.p2 + " " + s.p3;
            else if (!s.p2.isEmpty())
                reqDisplay = s.p2;
        } else if (t == "SET_RELAY" || t == "ENABLE_LOAD") {
            if (!s.p1.isEmpty() && !s.p2.isEmpty())
                reqDisplay = s.p1 + " → " + s.p2.toUpper();
        } else if (t == "SET_LOAD") {
            if (!s.p1.isEmpty() && !s.p3.isEmpty())
                reqDisplay = s.p1 + " " + s.p3 + " A";
        } else if (t == "ACTION" || t == "TEARDOWN") {
            reqDisplay = s.p1.isEmpty() ? s.p2 : s.p1;
        }
    }

    QVariantMap m;
    m["stt"]        = s.stt;
    m["type"]       = s.type;
    m["desc"]       = s.desc;
    m["p1"]         = s.p1;
    m["req"]        = reqDisplay;
    m["value"]      = displayValue;
    m["evaluation"] = s.evaluation;
    m["pass"]       = (s.evaluation == "ĐẠT");
    m["hasResult"]  = s.hasResult;
    return m;
}

// ── Signal / measurement reads ────────────────────────────────────────────────

double CmnAutoTestRunner::readSignalValue(const QString &name) const
{
    if (m_sig) {
        QVariantMap vmap = m_sig->signalVoltages();
        if (vmap.contains(name))
            return vmap.value(name).toDouble();
    }
    if (m_box) {
        QVariantMap vmap = m_box->signalVoltages();
        if (vmap.contains(name))
            return vmap.value(name).toDouble();
    }
    return 0.0;
}

double CmnAutoTestRunner::readLoadVoltage(int ch) const
{
    if (!m_mdl || ch < 1 || ch > 6) return 0.0;
    QVariantList cdata = m_mdl->channelData();
    if (ch - 1 >= cdata.size()) return 0.0;
    return cdata[ch - 1].toMap().value("measVoltageV").toDouble();
}

double CmnAutoTestRunner::readLoadCurrent(int ch) const
{
    if (!m_mdl || ch < 1 || ch > 6) return 0.0;
    QVariantList cdata = m_mdl->channelData();
    if (ch - 1 >= cdata.size()) return 0.0;
    return cdata[ch - 1].toMap().value("measCurrentA").toDouble();
}

int CmnAutoTestRunner::channelForLoad(const QString &loadName) const
{
    // LOAD_1 → 1, LOAD_2 → 2, ..., LOAD_6 → 6
    const QString ln = loadName.trimmed().toUpper();
    if (ln.startsWith("LOAD_")) {
        bool ok;
        int n = ln.mid(5).toInt(&ok);
        if (ok && n >= 1 && n <= 6) return n;
    }
    return -1;
}

// ── Requirement parsing ───────────────────────────────────────────────────────

CmnAutoTestRunner::Requirement CmnAutoTestRunner::parseRequirement(const QString &req) const
{
    Requirement r;
    if (req.isEmpty()) return r;

    const QString s = req.trimmed();

    static const QChar kPlusMinus(0x00B1);  // ±
    static const QChar kDivide   (0x00F7);  // ÷
    static const QChar kLessEq   (0x2264);  // ≤
    static const QChar kGreaterEq(0x2265);  // ≥

    // "Dòng đặt ±10%" → PERCENT_SETPOINT
    if (s.contains("Dòng đặt") || s.contains("dong dat")) {
        r.type = Requirement::PERCENT_SETPOINT;
        int pm = s.indexOf(kPlusMinus);
        if (pm < 0) pm = s.indexOf('+');
        if (pm >= 0) {
            QString numStr = s.mid(pm + 1);
            numStr.remove('%').remove(' ');
            bool ok;
            double tol = numStr.toDouble(&ok);
            if (ok) r.tol = tol;
        }
        return r;
    }

    // "27±2.7 V" → RANGE [24.3, 29.7]
    int pmIdx = s.indexOf(kPlusMinus);
    if (pmIdx > 0) {
        QString center = s.left(pmIdx).trimmed();
        QString rest   = s.mid(pmIdx + 1).trimmed();
        rest.remove('V').remove('A').remove('%').remove(' ');
        center.remove('V').remove('A').remove('%').remove(' ');
        bool ok1, ok2;
        double c = center.toDouble(&ok1);
        double d = rest.toDouble(&ok2);
        if (ok1 && ok2) {
            r.type = Requirement::RANGE;
            r.min  = c - d;
            r.max  = c + d;
            return r;
        }
    }

    // "19÷31 V" → RANGE [19, 31]
    int divIdx = s.indexOf(kDivide);
    if (divIdx < 0) divIdx = s.indexOf('~');
    if (divIdx > 0) {
        QString lo = s.left(divIdx).trimmed();
        QString hi = s.mid(divIdx + 1).trimmed();
        lo.remove('V').remove('A').remove('%').remove(' ');
        hi.remove('V').remove('A').remove('%').remove(' ');
        bool ok1, ok2;
        double lo_ = lo.toDouble(&ok1);
        double hi_ = hi.toDouble(&ok2);
        if (ok1 && ok2) {
            r.type = Requirement::RANGE;
            r.min  = lo_;
            r.max  = hi_;
            return r;
        }
    }

    // "< 1%" or "≤5%" → MAX_ONLY
    if (s.startsWith('<') || s.startsWith(kLessEq) || s.startsWith("<=")) {
        r.type = Requirement::MAX_ONLY;
        QString numStr = s;
        numStr.remove('<').remove(kLessEq).remove('=').remove('%').remove('V').remove('A').remove(' ');
        bool ok;
        double maxVal = numStr.toDouble(&ok);
        if (ok) { r.max = maxVal; return r; }
    }

    // ">= X" → MIN_ONLY — treat as RANGE with max=inf
    if (s.startsWith('>') || s.startsWith(kGreaterEq) || s.startsWith(">=")) {
        r.type = Requirement::RANGE;
        r.max  = 1e18;
        QString numStr = s;
        numStr.remove('>').remove(kGreaterEq).remove('=').remove('%').remove('V').remove('A').remove(' ');
        bool ok;
        double minVal = numStr.toDouble(&ok);
        if (ok) { r.min = minVal; return r; }
    }

    return r;
}

bool CmnAutoTestRunner::checkValue(double value, const Requirement &r, double setpoint) const
{
    switch (r.type) {
    case Requirement::NONE:
        return true;
    case Requirement::RANGE:
        return value >= r.min && value <= r.max;
    case Requirement::MAX_ONLY:
        return value <= r.max;
    case Requirement::PERCENT_SETPOINT:
        if (setpoint == 0.0) return false;
        return qAbs(value - setpoint) / qAbs(setpoint) * 100.0 <= r.tol;
    }
    return true;
}

// ── Session / settings ────────────────────────────────────────────────────────

bool CmnAutoTestRunner::loadLastSession()
{
    QSettings s("CMN_TESTING", "AutoRunner");
    QString path  = s.value("lastExcelPath").toString();
    QString sheet = s.value("lastSheetName").toString();
    if (path.isEmpty() || !QFileInfo::exists(path)) return false;
    if (!loadExcel(path)) return false;
    if (!sheet.isEmpty()) selectSheet(sheet);
    return true;
}

void CmnAutoTestRunner::setDefaultSaveDir(const QString &dir)
{
    if (m_defaultSaveDir == dir) return;
    m_defaultSaveDir = dir;
    QSettings("CMN_TESTING", "AutoRunner").setValue("defaultSaveDir", dir);
    emit defaultSaveDirChanged();
}

// ── Export results to Excel ───────────────────────────────────────────────────

bool CmnAutoTestRunner::saveResults(const QString &filePath)
{
#ifdef HAVE_QXLSX
    if (m_excelPath.isEmpty() || m_selectedSheet.isEmpty()) {
        emit logMessage("[AUTO] Chưa load file Excel — không thể lưu");
        emit saveFinished(false, {});
        return false;
    }

    // Xác định đường dẫn lưu
    QString savePath = filePath.trimmed();
    if (savePath.isEmpty()) {
        if (!m_defaultSaveDir.isEmpty()) {
            // Lưu vào thư mục đã cài, tên file = <tên gốc>_result.xlsx
            QFileInfo fi(m_excelPath);
            savePath = m_defaultSaveDir + "/" + fi.baseName() + "_result.xlsx";
        } else {
            // Không có thư mục cài → ghi đè file gốc
            savePath = m_excelPath;
        }
    }

    QXlsx::Document xlsx(m_excelPath);
    if (!xlsx.selectSheet(m_selectedSheet)) {
        emit logMessage("[AUTO] Không tìm thấy sheet: " + m_selectedSheet);
        emit saveFinished(false, {});
        return false;
    }

    // Ghi tiêu đề cột H, I nếu hàng 2 còn trống
    if (xlsx.read(2, 8).toString().isEmpty())
        xlsx.write(2, 8, "KẾT_QUẢ_ĐO");
    if (xlsx.read(2, 9).toString().isEmpty())
        xlsx.write(2, 9, "ĐÁNH_GIÁ");

    // Ghi kết quả từng bước vào đúng row (row = stt + 2 vì row 1=tiêu đề, row 2=header)
    int writtenCount = 0;
    for (int i = 0; i < m_steps.size(); ++i) {
        const TestStep &s = m_steps[i];
        if (!s.hasResult) continue;

        // Xác định row trong Excel: dựa vào stt nếu hợp lệ, không thì dùng i+3
        int row = (s.stt > 0) ? (s.stt + 2) : (i + 3);

        const QString t = s.type.toUpper().trimmed();
        if (t == "ACTION" || t == "SET_RELAY" || t == "ENABLE_LOAD") {
            // Không có giá trị số đo — chỉ ghi ĐÁNH_GIÁ
            xlsx.write(row, 9, s.evaluation);
        } else if (t == "SET_SOURCE" &&
                   s.p1.compare("Output_Enable", Qt::CaseInsensitive) == 0) {
            xlsx.write(row, 8, s.p2);          // "ON" / "OFF"
            xlsx.write(row, 9, s.evaluation);
        } else {
            xlsx.write(row, 8, s.resultValue);
            xlsx.write(row, 9, s.evaluation);
        }
        ++writtenCount;
    }

    bool ok = xlsx.saveAs(savePath);
    if (ok) {
        emit logMessage(QString("[AUTO] ✓ Đã lưu kết quả (%1 bước) → %2")
                        .arg(writtenCount).arg(savePath));
    } else {
        emit logMessage("[AUTO] ✗ Lỗi lưu file: " + savePath);
    }
    emit saveFinished(ok, savePath);
    return ok;
#else
    Q_UNUSED(filePath)
    emit logMessage("[AUTO] QXlsx không khả dụng — không thể xuất Excel");
    emit saveFinished(false, {});
    return false;
#endif
}
