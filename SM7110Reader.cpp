#include "SM7110Reader.h"
#include <QDebug>
#include <QRegularExpression>
#include <QThread>

SM7110Reader::SM7110Reader(QObject *parent)
    : QObject(parent)
    , m_isReading(false)
    , m_dischargeDelayMs(1000)
{
    // SM7110: 9600, 8N1 (giống RM3544)
    m_serial.setBaudRate(QSerialPort::Baud9600);
    m_serial.setDataBits(QSerialPort::Data8);
    m_serial.setParity(QSerialPort::NoParity);
    m_serial.setStopBits(QSerialPort::OneStop);
    m_serial.setFlowControl(QSerialPort::NoFlowControl);

    m_readTimeoutTimer.setSingleShot(true);
    m_readTimeoutTimer.setInterval(READ_TIMEOUT_MS);
    connect(&m_readTimeoutTimer, &QTimer::timeout, this, &SM7110Reader::onReadTimeout);
    connect(&m_serial, &QSerialPort::readyRead, this, &SM7110Reader::onDataReceived);
    
    // ⚠️ Timer xả điện - chờ sau khi tắt output
    m_dischargeTimer.setSingleShot(true);
    m_dischargeTimer.setInterval(m_dischargeDelayMs);
    connect(&m_dischargeTimer, &QTimer::timeout, this, &SM7110Reader::onDischargeTimerDone);
}

SM7110Reader::~SM7110Reader()
{
    if (m_serial.isOpen()) {
        m_serial.close();
    }
}

void SM7110Reader::setPortName(const QString &name)
{
    if (m_portName != name) {
        m_portName = name;
        emit portNameChanged();
    }
}

bool SM7110Reader::openPort()
{
    if (m_portName.isEmpty()) {
        qDebug() << "[SM7110] Lỗi: Chưa chọn cổng COM";
        emit errorOccurred(tr("Chưa chọn cổng COM"));
        return false;
    }
    if (m_serial.isOpen()) {
        qDebug() << "[SM7110] Đóng cổng COM cũ:" << m_serial.portName();
        m_serial.close();
        emit openChanged();
    }
    m_serial.setPortName(m_portName);
    qDebug() << "[SM7110] Đang mở cổng COM:" << m_portName << "Baudrate: 9600, 8N1";
    if (!m_serial.open(QIODevice::ReadWrite)) {
        qDebug() << "[SM7110] Lỗi khi mở cổng COM:" << m_serial.errorString();
        emit errorOccurred(m_serial.errorString());
        return false;
    }
    qDebug() << "[SM7110] Đã mở cổng COM thành công:" << m_portName;
    
    // Xóa buffer (không dùng msleep để tránh block UI)
    m_serial.clear();
    
    emit openChanged();
    return true;
}

void SM7110Reader::closePort()
{
    if (m_serial.isOpen()) {
        m_serial.close();
        emit openChanged();
    }
}

bool SM7110Reader::readResistance()
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở"));
        return false;
    }

    if (m_isReading) {
        emit errorOccurred(tr("Đang đọc giá trị, vui lòng đợi"));
        return false;
    }

    m_isReading = true;
    emit readingChanged();

    // Xóa dữ liệu cũ
    m_receivedData.clear();
    m_serial.clear();
    QByteArray oldData = m_serial.readAll();
    if (!oldData.isEmpty()) {
        qDebug() << "[SM7110] Xóa dữ liệu cũ:" << oldData.toHex();
    }

    // ═══ BƯỚC 1: :STARt - vào chế độ đo ═══
    // Manual: "After START, *TRG triggers one measurement"
    qDebug() << "[SM7110] Gửi :STARt - vào chế độ đo";
    m_serial.write(":STARt\r\n");
    m_serial.flush();
    m_serial.waitForReadyRead(200);
    m_serial.readAll(); // bỏ echo

    // ═══ BƯỚC 2: Trigger đo 1 lần ═══
    QByteArray trigCmd = "*TRG\r\n";
    qDebug() << "[SM7110] Trigger:" << trigCmd.trimmed();
    m_serial.write(trigCmd);
    m_serial.flush();
    m_serial.waitForReadyRead(100);
    m_serial.readAll(); // bỏ echo

    // ═══ BƯỚC 3: Đọc giá trị đo mới ═══
    QByteArray command = ":MEASure?\r\n";
    qDebug() << "[SM7110] Gửi lệnh:" << command.trimmed();
    qint64 written = m_serial.write(command);
    m_serial.flush();

    if (written != command.size()) {
        qDebug() << "[SM7110] Lỗi gửi lệnh:" << m_serial.errorString();
        m_isReading = false;
        emit readingChanged();
        emit errorOccurred(m_serial.errorString());
        return false;
    }

    qDebug() << "[SM7110] Đã trigger + gửi :MEASure?, đợi phản hồi...";
    m_readTimeoutTimer.start();
    return true;
}

void SM7110Reader::onDataReceived()
{
    if (!m_isReading) {
        return;
    }

    QByteArray data = m_serial.readAll();
    qDebug() << "[SM7110] Nhận dữ liệu:" << data.toHex() << "(" << QString::fromLatin1(data) << ")";
    m_receivedData.append(data);

    if (m_receivedData.contains('\r') || m_receivedData.contains('\n')) {
        QString responseStr = QString::fromLatin1(m_receivedData).trimmed();
        responseStr = responseStr.replace(QRegularExpression("[\\r\\n]+"), "");
        
        // Bỏ echo nếu có
        if (responseStr.startsWith(":MEAS") || responseStr.startsWith(":meas")) {
            qDebug() << "[SM7110] Echo lệnh, bỏ qua:" << responseStr;
            m_receivedData.clear();
            m_readTimeoutTimer.stop();
            m_readTimeoutTimer.start();
            return;
        }

        // Kiểm tra có phải số không
        bool looksLikeNumber = false;
        QString trimmed = responseStr.trimmed();
        if (!trimmed.isEmpty()) {
            QChar firstChar = trimmed[0];
            if (firstChar.isDigit() || firstChar == '+' || firstChar == '-' || firstChar == ' ' || 
                trimmed.contains('E') || trimmed.contains('e') || trimmed.contains('.')) {
                looksLikeNumber = true;
            }
        }

        if (!looksLikeNumber) {
            qDebug() << "[SM7110] Dữ liệu không giống số:" << responseStr;
            m_receivedData.clear();
            return;
        }

        qDebug() << "[SM7110] Đã nhận đủ dữ liệu, parse...";
        m_readTimeoutTimer.stop();
        m_isReading = false;
        emit readingChanged();

        double value = 0.0;
        if (parseValue(m_receivedData, value)) {
            qDebug() << "[SM7110] Parse thành công! Giá trị:" << value;
            emit resistanceRead(value);
        } else {
            qDebug() << "[SM7110] Parse thất bại:" << QString::fromLatin1(m_receivedData);
            emit errorOccurred(tr("Không thể parse giá trị từ SM7110: %1").arg(QString::fromLatin1(m_receivedData)));
        }
    }
}

void SM7110Reader::onReadTimeout()
{
    if (m_isReading) {
        qDebug() << "[SM7110] TIMEOUT! Không nhận được phản hồi sau" << READ_TIMEOUT_MS << "ms";
        m_isReading = false;
        emit readingChanged();
        emit errorOccurred(tr("Timeout khi đọc giá trị từ SM7110"));
    }
}

bool SM7110Reader::parseValue(const QByteArray &data, double &value)
{
    QString str = QString::fromLatin1(data).trimmed();
    str = str.replace(QRegularExpression("[\\r\\n]+"), "");
    
    // Space đầu → dấu +
    if (str.startsWith(' ')) {
        str = '+' + str.trimmed();
    }

    bool ok = false;
    value = str.toDouble(&ok);
    
    if (ok) {
        qDebug() << "[SM7110] Parse:" << str << "->" << value;
    } else {
        qDebug() << "[SM7110] Parse thất bại:" << str;
    }
    return ok;
}

// === Các lệnh cấu hình SM7110 ===

bool SM7110Reader::sendCommand(const QString &command)
{
    if (!m_serial.isOpen()) {
        qDebug() << "[SM7110] sendCommand: Cổng COM chưa mở";
        return false;
    }
    
    QByteArray cmd = command.toLatin1() + "\r\n";
    qDebug() << "[SM7110] Gửi lệnh:" << cmd.trimmed();
    qint64 written = m_serial.write(cmd);
    m_serial.flush();
    
    if (written != cmd.size()) {
        qDebug() << "[SM7110] Lỗi gửi:" << m_serial.errorString();
        return false;
    }
    
    QThread::msleep(100);
    QByteArray response = m_serial.readAll();
    if (!response.isEmpty()) {
        qDebug() << "[SM7110] Phản hồi:" << QString::fromLatin1(response).trimmed();
    }
    return true;
}

bool SM7110Reader::setVoltage(int voltage)
{
    qDebug() << "[SM7110] Set voltage:" << voltage << "V";
    return sendCommand(":VOLTage " + QString::number(voltage));
}

bool SM7110Reader::setOutput(bool on)
{
    qDebug() << "[SM7110] Set output:" << (on ? "ON" : "OFF");
    return sendCommand(":OUTPut " + QString(on ? "ON" : "OFF"));
}

bool SM7110Reader::setSpeed(const QString &speed)
{
    qDebug() << "[SM7110] Set speed:" << speed;
    return sendCommand(":SPEed " + speed);
}

bool SM7110Reader::setCurrentRange(const QString &range)
{
    qDebug() << "[SM7110] Set current range:" << range;
    return sendCommand(":CURRent:RANGe " + range);
}

bool SM7110Reader::setCurrentRangeAuto(bool on)
{
    qDebug() << "[SM7110] Set current range auto:" << (on ? "ON" : "OFF");
    return sendCommand(":CURRent:RANGe:AUTO " + QString(on ? "ON" : "OFF"));
}

bool SM7110Reader::configure(int voltage, const QString &speed)
{
    qDebug() << "[SM7110] Cấu hình: voltage=" << voltage << "V, speed=" << speed;
    bool ok = true;
    ok = setVoltage(voltage) && ok;
    if (!speed.isEmpty()) {
        ok = setSpeed(speed) && ok;
    }
    
    // Set trigger source = BUS (để PC trigger từng lần bằng *TRG)
    // KHÔNG dùng :STARt (continuous mode) vì sẽ phóng điện liên tục!
    qDebug() << "[SM7110] Set trigger source = BUS";
    ok = sendCommand(":TRIGger EXTernal") && ok;
    
    return ok;
}

// === DELAY: thời gian chờ trước khi đo ===
// Sau khi áp điện áp test, máy chờ delay giây để điện trở ổn định
bool SM7110Reader::setTrigDelay(double seconds)
{
    if (seconds < 0) seconds = 0;
    if (seconds > 999) seconds = 999;
    qDebug() << "[SM7110] Set trigger delay:" << seconds << "s";
    return sendCommand(":TRIG:DEL " + QString::number(seconds, 'f', 1));
}

// === AVG: số lần lấy trung bình ===
// Máy đo n lần rồi tính average để giảm nhiễu
bool SM7110Reader::setAverageCount(int count)
{
    if (count < 1) count = 1;
    if (count > 100) count = 100;
    qDebug() << "[SM7110] Set average count:" << count;
    return sendCommand(":AVER:COUN " + QString::number(count));
}

bool SM7110Reader::setAverageEnabled(bool on)
{
    qDebug() << "[SM7110] Set average:" << (on ? "ON" : "OFF");
    return sendCommand(":AVER " + QString(on ? "ON" : "OFF"));
}

// === SEQ: chế độ đo liên tục ===
bool SM7110Reader::setSequenceMode(bool on)
{
    qDebug() << "[SM7110] Set sequence mode:" << (on ? "ON" : "OFF");
    return sendCommand(":INIT:CONT " + QString(on ? "ON" : "OFF"));
}

// === Cấu hình đầy đủ (voltage + speed + delay + avg) ===
bool SM7110Reader::configureAdvanced(int voltage, const QString &speed,
                                      double trigDelay, int avgCount, bool avgEnabled)
{
    qDebug() << "[SM7110] Cấu hình nâng cao: voltage=" << voltage << "V, speed=" << speed
             << ", delay=" << trigDelay << "s, avg=" << avgCount << (avgEnabled ? "ON" : "OFF");
    bool ok = true;
    ok = setVoltage(voltage) && ok;
    if (!speed.isEmpty()) {
        ok = setSpeed(speed) && ok;
    }
    ok = setTrigDelay(trigDelay) && ok;
    ok = setAverageCount(avgCount) && ok;
    ok = setAverageEnabled(avgEnabled) && ok;
    
    // Set trigger source = BUS (PC trigger từng lần)
    // KHÔNG dùng :STARt để tránh phóng điện liên tục!
    qDebug() << "[SM7110] Set trigger source = BUS";
    ok = sendCommand(":TRIGger EXTernal") && ok;
    
    // Tắt loa bíp (Comparator/System) tránh kêu
    qDebug() << "[SM7110] Tắt beeper";
    sendCommand(":COMParator:BEEPer OFF"); // Format chung của máy đo Hioki trở kháng
    sendCommand(":SYSTem:BEEPer:STATe OFF"); // Đề phòng lệnh SYSTem
    
    return ok;
}

// ======================================
// ⚠️ AN TOÀN ĐIỆN ÁP CAO: Xả điện
// ======================================

void SM7110Reader::setDischargeDelayMs(int ms)
{
    if (ms < 100) ms = 100;  // Tối thiểu 100ms
    if (ms > 10000) ms = 10000; // Tối đa 10 giây
    if (m_dischargeDelayMs != ms) {
        m_dischargeDelayMs = ms;
        m_dischargeTimer.setInterval(ms);
        qDebug() << "[SM7110] Discharge delay set to" << ms << "ms";
        emit dischargeDelayMsChanged();
    }
}

void SM7110Reader::discharge()
{
    qDebug() << "[SM7110] ⚠️ Bắt đầu xả điện (discharge)...";
    
    if (m_serial.isOpen()) {
        // Bước 1: :STOP - THOÁT chế độ đo (dừng áp điện áp!)
        QByteArray stopCmd = ":STOP\r\n";
        m_serial.write(stopCmd);
        m_serial.flush();
        qDebug() << "[SM7110] Đã gửi :STOP - thoát chế độ đo";
        QThread::msleep(50);
        m_serial.readAll();
        
        // Bước 2: :OUTPut OFF - tắt output (backup an toàn)
        QByteArray offCmd = ":OUTPut OFF\r\n";
        m_serial.write(offCmd);
        m_serial.flush();
        qDebug() << "[SM7110] Đã gửi :OUTPut OFF - tắt điện áp cao";
        QThread::msleep(50);
        m_serial.readAll();
    } else {
        qDebug() << "[SM7110] Cổng COM không mở, bỏ qua";
    }
    
    // Bước 3: Chờ thời gian xả điện
    qDebug() << "[SM7110] Chờ xả điện" << m_dischargeDelayMs << "ms...";
    m_dischargeTimer.start();
}

void SM7110Reader::onDischargeTimerDone()
{
    qDebug() << "[SM7110] ✅ Xả điện hoàn tất! An toàn để chuyển relay/tháo dây.";
    emit dischargeComplete();
}
