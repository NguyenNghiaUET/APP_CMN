#include "McuSender.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>
#include <QList>
#include <QMap>
#include <QString>
#include <QChar>
#include <QVariant>
#include <QVariantMap>
#include <QByteArray>
#include <QtGlobal>
#include <QDateTime>
#include <QStringList>
#include <QPair>
#include <cstring>

// ── Relay pin map ─────────────────────────────────────────────────────────────
// TODO: cập nhật số chân thực tế theo sơ đồ phần cứng
const QMap<QString, int> McuSender::kRelayPinMap = {
    {"VLS_ON",     1},
    {"Bat1_ON",    2},
    {"Bat2_ON",    3},
    {"Gen_ON",     4},
    {"VLS_BatON",  5},
    {"VLS_BatOFF", 6},
    {"MPSS_TBKT",  7},
    {"CMD_ERM",    8},
    {"CMD_PUMP",   9},
    {"CCBH_in",   10},
    {"CMD_PPA",   11},
    {"CMD_Pyro1", 12},
    {"CMD_Pyro2", 13},
    {"CMD_TJE",   14},
    {"CMD_FUZE",  15},
};

// ── CRC8 XOR — khớp calc_crc trên MCU:
//   crc = STX ^ total_msg ^ seq ^ cmd ^ len
//   for i in 0..len-1: crc ^= data[i]
// port = 0x00 cho các packet không có PORT field (backward compat)
static quint8 calc_crc(quint8 stx, quint8 total_msg, quint8 seq,
                        quint8 cmd, quint8 len, const QByteArray &data,
                        quint8 port = 0x00)
{
    quint8 crc = stx ^ total_msg ^ seq ^ cmd ^ port ^ len;
    for (int i = 0; i < static_cast<int>(len); i++)
        crc ^= static_cast<quint8>(data.at(i));
    return crc;
}

McuSender::McuSender(QObject *parent) : QObject(parent)
{
    // UART: 8 data bits, no parity, 1 stop bit (8N1), no flow control
    m_serial.setBaudRate(QSerialPort::Baud115200);
    m_serial.setDataBits(QSerialPort::Data8);
    m_serial.setParity(QSerialPort::NoParity);
    m_serial.setStopBits(QSerialPort::OneStop);
    m_serial.setFlowControl(QSerialPort::NoFlowControl);
    
    // Kết nối signal readyRead để nhận data từ MCU
    connect(&m_serial, &QSerialPort::readyRead, this, &McuSender::onReadyRead);

    // Poll timer - fallback cho trường hợp readyRead không trigger trên Windows
    m_pollTimer.setInterval(1000); // 100ms
    connect(&m_pollTimer, &QTimer::timeout, this, [this]() {
        if (m_serial.isOpen() && m_serial.bytesAvailable() > 0) {
            qDebug() << "[POLL] Phat hien data trong serial port! bytesAvailable =" << m_serial.bytesAvailable();
            onReadyRead();
        }
    });
    m_pollTimer.start();
}

void McuSender::setPortName(const QString &name)
{
    if (m_portName != name) {
        // Nếu cổng COM đang mở và đang set portName mới khác với portName hiện tại
        // thì đóng cổng COM cũ trước
        if (m_serial.isOpen() && !name.isEmpty() && name != m_portName) {
            // qDebug() << QString("[McuSender] Dong cong COM cu (%1) truoc khi chuyen sang cong moi (%2)").arg(m_portName).arg(name);
            m_serial.close();
            emit openChanged();
        }
        
        m_portName = name;
        emit portNameChanged();
    }
}

void McuSender::setBaudRate(int rate)
{
    if (m_baudRate != rate) {
        m_baudRate = rate;
        m_serial.setBaudRate(rate);
        emit baudRateChanged();
    }
}

bool McuSender::isOpen() const
{
    return m_serial.isOpen();
}

QStringList McuSender::getAvailablePorts() const
{
    QStringList portNames;
    const auto infos = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &info : infos) {
        portNames.append(info.portName());
    }
    // Sắp xếp lại
    portNames.sort();
    return portNames;
}

bool McuSender::openPort()
{
    // qDebug() << QString("[McuSender::openPort] Bat dau mo cong COM: %1").arg(m_portName);
    
    if (m_portName.isEmpty()) {
        // qDebug() << QString("[McuSender::openPort] ERROR: Chua chon cong COM!");
        emit errorOccurred(tr("Chưa chọn cổng COM"));
        return false;
    }
    
    if (m_serial.isOpen()) {
        // qDebug() << QString("[McuSender::openPort] Cong COM dang mo, dong lai truoc...");
        m_serial.close();
        emit openChanged();
    }
    
    m_serial.setPortName(m_portName);
    // qDebug() << QString("[McuSender::openPort] Dat ten cong: %1").arg(m_portName);
    
    // Cấu hình cổng COM
    m_serial.setBaudRate(QSerialPort::Baud115200);
    m_serial.setDataBits(QSerialPort::Data8);
    m_serial.setParity(QSerialPort::NoParity);
    m_serial.setStopBits(QSerialPort::OneStop);
    m_serial.setFlowControl(QSerialPort::NoFlowControl);
    
    // qDebug() << QString("[McuSender::openPort] Dang mo cong COM %1...").arg(m_portName);
    if (!m_serial.open(QIODevice::ReadWrite)) {
        qDebug() << QString("[McuSender::openPort] ERROR: Khong the mo cong COM %1: %2").arg(m_portName).arg(m_serial.errorString());
        emit errorOccurred(tr("Không thể mở cổng COM %1: %2").arg(m_portName).arg(m_serial.errorString()));
        return false;
    }
    
    // Kiểm tra xem port có thực sự mở được không
    if (!m_serial.isOpen()) {
        qDebug() << QString("[McuSender::openPort] ERROR: Cong COM %1 khong the mo duoc sau khi goi open()").arg(m_portName);
        emit errorOccurred(tr("Cổng COM %1 không thể mở được").arg(m_portName));
        return false;
    }
    
    qDebug() << QString("✓ Đã mở cổng COM: %1 (ReadWrite)").arg(m_portName);
    qDebug() << QString("  BaudRate=%1, DataBits=%2, Parity=%3, StopBits=%4, FlowControl=%5")
                .arg(m_serial.baudRate()).arg(m_serial.dataBits())
                .arg(m_serial.parity()).arg(m_serial.stopBits()).arg(m_serial.flowControl());
    
    // Clear buffer cũ
    m_serial.clear();
    m_receiveBuffer.clear();
    qDebug() << "[McuSender] Da clear buffer serial + receiveBuffer";
    
    emit openChanged();
    return true;
}

void McuSender::closePort()
{
    if (m_serial.isOpen()) {
        m_serial.close();
        emit openChanged();
    }
}



bool McuSender::sendPinPairs(const QVariantList &pairs)
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở"));
        return false;
    }
    
    // Kiểm tra xem cổng COM đang mở có đúng với portName hiện tại không
    if (m_serial.portName() != m_portName) {
        // qDebug() << QString("[McuSender] ERROR: Cong COM dang mo (%1) khac voi portName hien tai (%2)!").arg(m_serial.portName()).arg(m_portName);
        emit errorOccurred(tr("Cổng COM đang mở (%1) khác với cổng COM được cấu hình (%2). Vui lòng đóng và mở lại cổng COM.").arg(m_serial.portName()).arg(m_portName));
        return false;
    }
    QJsonArray arr;
    for (const QVariant &v : pairs) {
        int pinA = -1, pinB = -1;
        if (v.canConvert<QVariantList>()) {
            QVariantList lst = v.toList();
            if (lst.size() >= 2) {
                pinA = lst.at(0).toInt();
                pinB = lst.at(1).toInt();
            }
        } else if (v.canConvert<QVariantMap>()) {
            QVariantMap m = v.toMap();
            pinA = m.value(QStringLiteral("pinA")).toInt();
            pinB = m.value(QStringLiteral("pinB")).toInt();
        }
        if (pinA >= 0 && pinB >= 0) {
            QJsonArray pair;
            pair.append(pinA);
            pair.append(pinB);
            arr.append(pair);
        }
    }
    if (arr.isEmpty()) {
        emit errorOccurred(tr("Không có cặp chân hợp lệ để gửi"));
        return false;
    }
    QJsonDocument doc(arr);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);
    const int dataLen = jsonData.size();
    if (dataLen > 65535) {
        emit errorOccurred(tr("Dữ liệu JSON quá dài (tối đa 65535 byte)"));
        return false;
    }
    // Packet: [0xAA][length_lo][length_hi][data][CRC8]
    const quint8 header = 0xAA;
    const quint8 len_lo = static_cast<quint8>(dataLen & 0xFF);
    const quint8 len_hi = static_cast<quint8>((dataLen >> 8) & 0xFF);
    QByteArray payload;
    payload.append(static_cast<char>(header));
    payload.append(static_cast<char>(len_lo));
    payload.append(static_cast<char>(len_hi));
    payload.append(jsonData);
    // CRC: STX ^ len_lo ^ len_hi ^ XOR(data)
    quint8 crc = calc_crc(header, len_lo, len_hi, 0x00, static_cast<quint8>(dataLen), jsonData);
    payload.append(static_cast<char>(crc));

    // Lưu lại trong trường hợp cần gửi lại
    m_lastSentPacket = payload;

    qint64 written = m_serial.write(payload);
    m_serial.flush();
    if (written != payload.size()) {
        emit errorOccurred(m_serial.errorString());
        return false;
    }
    emit sent(arr.size());
    return true;
}

bool McuSender::sendTestScripts(const QVariantList &scripts, bool isCalibration)
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở. Vui lòng mở cổng COM trước khi gửi dữ liệu."));
        return false;
    }
    if (m_serial.portName() != m_portName) {
        emit errorOccurred(tr("Cổng COM đang mở (%1) khác với cổng COM được cấu hình (%2).").arg(m_serial.portName()).arg(m_portName));
        return false;
    }

    // Protocol frame: A5 | TOTAL_MSG | SEQ | CMD | LEN | DATA[LEN] | CRC | 5A
    const quint8 STX = 0xA5;
    const quint8 ETX = 0x5A;

    struct ScriptInfo {
        quint8 cmd;
        quint8 portByte;
        int portPinA;
        int portPinB;
        QString scriptType;
    };

    QList<ScriptInfo> measurements;

    for (const QVariant &v : scripts) {
        if (!v.canConvert<QVariantMap>()) continue;
        QVariantMap s = v.toMap();
        QString st = s.value(QStringLiteral("scriptType")).toString();

        if (st.contains(QStringLiteral("_header")) || st.isEmpty()) continue;
        if (st == QStringLiteral("notification")) continue;
        if (st != QStringLiteral("continuity") && st != QStringLiteral("sheath_insulation")) continue;

        int portPinA = s.value(QStringLiteral("portPinA"), -1).toInt();
        int portPinB = s.value(QStringLiteral("portPinB"), -1).toInt();
        bool hasColA = !s.value(QStringLiteral("portLabelA")).toString().isEmpty();
        bool hasColB = !s.value(QStringLiteral("portLabelB")).toString().isEmpty();

        // CMD
        quint8 cmd;
        if (isCalibration) {
            cmd = 0x8B;
        } else if (st == QStringLiteral("continuity")) {
            cmd = 0x8E;
        } else {
            cmd = 0x8F; // sheath_insulation
        }

        // portByte
        quint8 portByte;
        if (st == QStringLiteral("sheath_insulation")) {
            portByte = (portPinA > 0) ? 0xAA : 0xBB;
        } else {
            // continuity: cross-port if both columns present
            if (hasColA && hasColB)       portByte = 0xAB;
            else if (hasColA)             portByte = 0xAA;
            else                          portByte = 0xBB;
        }

        measurements.append({ cmd, portByte, portPinA, portPinB, st });
    }

    if (measurements.isEmpty()) {
        emit errorOccurred(tr("Không có script hợp lệ để gửi"));
        return false;
    }

    m_packetQueue.clear();
    m_currentQueueIndex = 0;
    m_retryCount = 0;

    const quint8 total = static_cast<quint8>(qMin(measurements.size(), 255));

    for (int i = 0; i < measurements.size(); i++) {
        const ScriptInfo &si = measurements[i];
        const quint8 seq = static_cast<quint8>(i + 1);

        // DATA = chỉ pin bytes (portByte tách riêng thành PORT field)
        QByteArray data;
        if (si.scriptType == QStringLiteral("sheath_insulation")) {
            quint8 pin = (si.portPinA > 0) ? static_cast<quint8>(si.portPinA)
                                            : static_cast<quint8>(si.portPinB);
            data.append(static_cast<char>(pin));
            data.append(static_cast<char>(0x00)); // ground = kênh 0
        } else {
            // continuity — gửi cả 2 chân
            if (si.portPinA >= 0) data.append(static_cast<char>(static_cast<quint8>(si.portPinA)));
            if (si.portPinB >= 0) data.append(static_cast<char>(static_cast<quint8>(si.portPinB)));
        }

        quint8 len = static_cast<quint8>(data.size()); // LEN = số byte data, không tính PORT
        quint8 crc = calc_crc(STX, total, seq, si.cmd, len, data, si.portByte);

        // Frame: STX | TOTAL | SEQ | CMD | PORT | LEN | DATA | CRC | ETX
        QByteArray packet;
        packet.append(static_cast<char>(STX));
        packet.append(static_cast<char>(total));
        packet.append(static_cast<char>(seq));
        packet.append(static_cast<char>(si.cmd));
        packet.append(static_cast<char>(si.portByte)); // PORT field riêng
        packet.append(static_cast<char>(len));
        packet.append(data);
        packet.append(static_cast<char>(crc));
        packet.append(static_cast<char>(ETX));

        m_packetQueue.append(packet);

        qDebug() << QString("[Queue %1/%2] cmd=0x%3 port=0x%4 len=%5 data=%6 CRC=0x%7")
                    .arg(seq).arg(total)
                    .arg(si.cmd, 2, 16, QChar('0'))
                    .arg(si.portByte, 2, 16, QChar('0'))
                    .arg(len)
                    .arg(QString(data.toHex(' ').toUpper()))
                    .arg(crc, 2, 16, QChar('0'));
        qDebug() << "[Queue] HEX:" << packet.toHex(' ').toUpper();
    }

    qDebug() << QString("[McuSender] Da build %1 packets. Bat dau gui packet 1...").arg(m_packetQueue.size());

    m_isSendingQueue = true;
    emit queueChanged();

    if (!sendRawPacket(m_packetQueue[0])) {
        cancelQueue();
        return false;
    }

    emit sent(measurements.size());
    return true;
}

bool McuSender::sendRawPacket(const QByteArray &packet)
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở"));
        return false;
    }
    
    // Debug hex dump
    QString hexDump;
    for (int i = 0; i < packet.size(); i++) {
        quint8 byte = static_cast<quint8>(packet.at(i));
        hexDump += QString("%1 ").arg(byte, 2, 16, QChar('0')).toUpper();
    }
    qDebug() << QString(">>> GUI DEN MCU (%1 bytes): %2").arg(packet.size()).arg(hexDump.trimmed());
    
    // Lưu gói tin cũ để gửi lại nếu bị lỗi
    m_lastSentPacket = packet;
    
    qint64 written = m_serial.write(packet);
    if (written < 0) {
        emit errorOccurred(tr("Lỗi ghi vào cổng COM: %1").arg(m_serial.errorString()));
        return false;
    }
    
    m_serial.flush();
    
    if (written != packet.size()) {
        emit errorOccurred(tr("Lỗi gửi: chỉ gửi được %1/%2 byte").arg(written).arg(packet.size()));
        return false;
    }
    
    return true;
}

void McuSender::sendNextQueuedPacket()
{
    if (!m_isSendingQueue) return;

    m_retryCount = 0;
    m_currentQueueIndex++;
    emit queueChanged();
    
    if (m_currentQueueIndex >= m_packetQueue.size()) {
        // Tất cả packets đã gửi và ACK xong
        qDebug() << QString("[McuSender] === TAT CA %1 PACKETS DA GUI VA ACK XONG ===").arg(m_packetQueue.size());
        m_isSendingQueue = false;
        emit queueChanged();
        emit allPacketsSent();
        return;
    }
    
    // Gửi packet tiếp theo
    qDebug() << QString("[McuSender] ACK nhan - gui packet %1/%2...")
                .arg(m_currentQueueIndex + 1).arg(m_packetQueue.size());
    
    if (!sendRawPacket(m_packetQueue[m_currentQueueIndex])) {
        cancelQueue();
    }
}

bool McuSender::sendRelayOnList(const QVariantList &onPins)
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở"));
        return false;
    }

    const quint8 STX   = 0xA5;
    const quint8 ETX   = 0x5A;
    const quint8 total = 0x01;
    const quint8 seq   = 0x01;
    const quint8 cmd   = CMD_RELAY;
    const quint8 port  = 0x00;

    // Data = chỉ các pin đang ON (MCU tự hiểu pin không có trong list → OFF)
    QByteArray data;
    for (const QVariant &v : onPins)
        data.append(static_cast<char>(static_cast<quint8>(v.toInt())));

    const quint8 len = static_cast<quint8>(data.size());
    const quint8 crc = calc_crc(STX, total, seq, cmd, len, data, port);

    QByteArray packet;
    packet.append(static_cast<char>(STX));
    packet.append(static_cast<char>(total));
    packet.append(static_cast<char>(seq));
    packet.append(static_cast<char>(cmd));
    packet.append(static_cast<char>(port));
    packet.append(static_cast<char>(len));
    packet.append(data);
    packet.append(static_cast<char>(crc));
    packet.append(static_cast<char>(ETX));

    m_sendingRelay = true;
    m_relayRetry   = 0;

    qDebug() << QString("[RELAY] Gửi %1 pin ON | HEX: %2")
                .arg(onPins.size())
                .arg(QString(packet.toHex(' ').toUpper()));

    return sendRawPacket(packet);
}

bool McuSender::sendRelayFrame(int pin, bool state)
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở"));
        return false;
    }

    const quint8 STX   = 0xA5;
    const quint8 ETX   = 0x5A;
    const quint8 total = 0x01;
    const quint8 seq   = 0x01;
    const quint8 cmd   = CMD_RELAY;
    const quint8 port  = 0x00;

    QByteArray data;
    data.append(static_cast<char>(static_cast<quint8>(pin)));
    data.append(static_cast<char>(state ? 0xA0 : 0x00));
    const quint8 len = static_cast<quint8>(data.size());
    const quint8 crc = calc_crc(STX, total, seq, cmd, len, data, port);

    QByteArray packet;
    packet.append(static_cast<char>(STX));
    packet.append(static_cast<char>(total));
    packet.append(static_cast<char>(seq));
    packet.append(static_cast<char>(cmd));
    packet.append(static_cast<char>(port));
    packet.append(static_cast<char>(len));
    packet.append(data);
    packet.append(static_cast<char>(crc));
    packet.append(static_cast<char>(ETX));

    m_sendingRelay = true;
    m_relayRetry   = 0;

    qDebug() << QString("[RELAY] pin=%1 %2 | HEX: %3")
                .arg(pin).arg(state ? "ON" : "OFF")
                .arg(QString(packet.toHex(' ').toUpper()));

    return sendRawPacket(packet);
}

bool McuSender::sendRelayByName(const QString &name, bool state)
{
    int pin = kRelayPinMap.value(name, -1);
    if (pin < 0) {
        emit errorOccurred(tr("Relay '%1' không có trong pin map").arg(name));
        return false;
    }
    return sendRelayFrame(pin, state);
}

int McuSender::relayPin(const QString &name) const
{
    return kRelayPinMap.value(name, -1);
}

void McuSender::sendNextScript()
{
    if (!m_isSendingQueue) return;

    m_retryCount = 0;
    m_currentQueueIndex++;
    emit queueChanged();

    if (m_currentQueueIndex >= m_packetQueue.size()) {
        qDebug() << QString("[McuSender] === TAT CA %1 PACKETS DA GUI VA ACK XONG ===").arg(m_packetQueue.size());
        m_isSendingQueue = false;
        emit queueChanged();
        emit allPacketsSent();
        return;
    }

    qDebug() << QString("[McuSender] sendNextScript: gui packet %1/%2...")
                .arg(m_currentQueueIndex + 1).arg(m_packetQueue.size());

    if (!sendRawPacket(m_packetQueue[m_currentQueueIndex])) {
        cancelQueue();
    }
}

void McuSender::cancelQueue()
{
    if (m_isSendingQueue) {
        qDebug() << "[McuSender] Huy queue - dung gui packets";
        m_isSendingQueue = false;
        m_packetQueue.clear();
        m_currentQueueIndex = 0;
        emit queueChanged();
    }
}

void McuSender::onReadyRead()
{
    // Đọc tất cả data có sẵn từ cổng COM
    QByteArray newData = m_serial.readAll();
    if (newData.isEmpty()) {
        return;
    }
    
    // Thêm vào buffer
    m_receiveBuffer.append(newData);
    
    // Debug: In ra data nhận được từ MCU
    QString hexDump;
    for (int i = 0; i < newData.size(); i++) {
        quint8 byte = static_cast<quint8>(newData.at(i));
        hexDump += QString("%1 ").arg(byte, 2, 16, QChar('0')).toUpper();
    }
    qDebug() << QString("<<< RAW TU MCU (%1 bytes): %2").arg(newData.size()).arg(hexDump.trimmed());
    qDebug() << QString("<<< Buffer hien tai (%1 bytes)").arg(m_receiveBuffer.size());
    
    // Xử lý buffer để tìm các packet hợp lệ
    processReceivedData();
}


void McuSender::processReceivedData()
{
    // Xử lý 2 loại packet:
    // 1. ACK/NAK: A5 | CMD(AA/BB) | SEQ | ERR | CRC | 5A = 6 bytes
    // 2. Packet dài (legacy): 0xAA | total | seq | cmd | len | data | CRC
    const quint8 startByteAck  = 0xA5;
    const quint8 startByteLong = 0xAA;
    const int ackPacketSize   = 6;
    const int headerSizeLong  = 5; // startByte + totalMessages + messageIndex + cmd + dataLength
    const int minPacketSize   = ackPacketSize;
    
    int packetsProcessed = 0;
    int maxIterations = 100; // Giới hạn số lần lặp để tránh vòng lặp vô hạn
    
    while (m_receiveBuffer.size() >= minPacketSize && packetsProcessed < maxIterations) {
        packetsProcessed++;
        
        // Tìm startByte hợp lệ từ đầu buffer
        quint8 firstByte = static_cast<quint8>(m_receiveBuffer.at(0));
        if (firstByte != startByteAck && firstByte != startByteLong) {
            int startIdx = -1;
            for (int i = 1; i <= m_receiveBuffer.size() - minPacketSize; i++) {
                quint8 b = static_cast<quint8>(m_receiveBuffer.at(i));
                if (b == startByteAck || b == startByteLong) {
                    startIdx = i;
                    break;
                }
            }

            if (startIdx == -1) {
                m_receiveBuffer.clear();
                return;
            }

            m_receiveBuffer.remove(0, startIdx);
            firstByte = static_cast<quint8>(m_receiveBuffer.at(0));
        }

        // === ACK/NAK frame (A5 CMD SEQ ERR CRC 5A) ===
        if (firstByte == startByteAck) {
            if (m_receiveBuffer.size() < ackPacketSize) {
                return; // chờ thêm data
            }

            quint8 cmd  = static_cast<quint8>(m_receiveBuffer.at(1));
            quint8 seq  = static_cast<quint8>(m_receiveBuffer.at(2));
            quint8 err  = static_cast<quint8>(m_receiveBuffer.at(3));
            quint8 crc  = static_cast<quint8>(m_receiveBuffer.at(4));
            quint8 etx  = static_cast<quint8>(m_receiveBuffer.at(5));

            quint8 expectedCrc = 0xA5 ^ cmd ^ seq ^ err;

            if (etx != 0x5A || crc != expectedCrc) {
                qDebug() << QString("[MCU] A5 frame invalid: cmd=0x%1 seq=%2 err=0x%3 crc=0x%4 exp=0x%5 etx=0x%6")
                            .arg(cmd, 2, 16, QChar('0')).arg(seq)
                            .arg(err, 2, 16, QChar('0')).arg(crc, 2, 16, QChar('0'))
                            .arg(expectedCrc, 2, 16, QChar('0')).arg(etx, 2, 16, QChar('0'));
                m_receiveBuffer.remove(0, 1);
                continue;
            }

            qDebug() << QString("<<< MCU %1: seq=%2 err=0x%3")
                        .arg(cmd == 0xAA ? "ACK" : "NAK").arg(seq)
                        .arg(err, 2, 16, QChar('0'));

            m_receiveBuffer.remove(0, ackPacketSize);

            // ── Build log string ──────────────────────────────────────────
            auto errName = [](quint8 e) -> QString {
                switch (e) {
                case 0x01: return "CRC sai";
                case 0x02: return "Timeout";
                case 0x03: return "Hết retry";
                case 0x04: return "MCU bận";
                default:   return QString("0x%1").arg(e, 2, 16, QChar('0')).toUpper();
                }
            };

            if (cmd == 0xAA) {
                // ── ACK ───────────────────────────────────────────────────
                QString rawHex = QString("A5 AA %1 00 %2 5A")
                    .arg(seq, 2, 16, QChar('0')).toUpper()
                    .arg(crc, 2, 16, QChar('0')).toUpper();

                if (m_sendingRelay) {
                    m_sendingRelay = false;
                    m_relayRetry   = 0;
                    emit mcuFrameReceived(rawHex, QString("ACK relay seq=%1").arg(seq));
                    qDebug() << "[MCU] RELAY ACK OK";
                    emit mcuRelayAck();
                } else {
                    m_retryCount = 0;
                    emit mcuFrameReceived(rawHex, QString("ACK seq=%1").arg(seq));
                    qDebug() << "[MCU] ACK OK — QML đọc máy đo rồi gọi sendNextScript()";
                    emit mcuAckReceived();
                }

            } else if (cmd == 0xBB) {
                // ── NAK ───────────────────────────────────────────────────
                QString rawHex = QString("A5 BB %1 %2 %3 5A")
                    .arg(seq, 2, 16, QChar('0')).toUpper()
                    .arg(err, 2, 16, QChar('0')).toUpper()
                    .arg(crc, 2, 16, QChar('0')).toUpper();

                if (m_sendingRelay) {
                    m_relayRetry++;
                    emit mcuFrameReceived(rawHex, QString("NAK relay [%1] retry=%2/%3")
                        .arg(errName(err)).arg(m_relayRetry).arg(MAX_RETRIES));
                    qDebug() << QString("[MCU] RELAY NAK err=0x%1 retry %2/%3")
                                .arg(err, 2, 16, QChar('0')).arg(m_relayRetry).arg(MAX_RETRIES);
                    if (m_relayRetry < MAX_RETRIES) {
                        if (!m_lastSentPacket.isEmpty())
                            sendRawPacket(m_lastSentPacket);
                    } else {
                        m_sendingRelay = false;
                        m_relayRetry   = 0;
                        emit mcuRelayNak(static_cast<int>(err));
                    }
                } else {
                    emit mcuFrameReceived(rawHex, QString("NAK seq=%1 [%2] retry=%3/%4")
                        .arg(seq).arg(errName(err)).arg(m_retryCount + 1).arg(MAX_RETRIES));
                    emit mcuNakReceived(static_cast<int>(err));
                    m_retryCount++;
                    qDebug() << QString("[MCU] NAK err=0x%1 retry %2/%3")
                                .arg(err, 2, 16, QChar('0')).arg(m_retryCount).arg(MAX_RETRIES);
                    if (m_retryCount < MAX_RETRIES) {
                        if (!m_lastSentPacket.isEmpty())
                            sendRawPacket(m_lastSentPacket);
                    } else {
                        qDebug() << "[MCU] Max retries reached, skipping seq" << (m_currentQueueIndex + 1);
                        emit mcuNakSkipped(m_currentQueueIndex + 1);
                        sendNextQueuedPacket();
                    }
                }
            }
            continue;
        }

        // === Xử lý packet dài (0xAA ...) ===
        const int headerSize = headerSizeLong;
        
        // Kiểm tra có đủ data để đọc header không
        if (m_receiveBuffer.size() < headerSize) {
            // qDebug() << QString("Buffer chua du header (%1/%2 bytes), cho them data").arg(m_receiveBuffer.size()).arg(headerSize);
            return; // Chờ thêm data
        }
        
        quint8 totalMessages = static_cast<quint8>(m_receiveBuffer.at(1));
        quint8 messageIndex = static_cast<quint8>(m_receiveBuffer.at(2));
        quint8 cmd = static_cast<quint8>(m_receiveBuffer.at(3));
        quint8 dataLength = static_cast<quint8>(m_receiveBuffer.at(4));
        
        // Kiểm tra dataLength hợp lệ (tối đa 128 byte)
        if (dataLength > 128) {
            // qDebug() << QString("DataLength khong hop le: %1, bo qua byte dau tien").arg(dataLength);
            // DataLength không hợp lệ, bỏ qua byte này và tìm lại startByte
            m_receiveBuffer.remove(0, 1); // 
            continue;
        }
        
        const int totalPacketSize = headerSize + dataLength + 1; // header + data + CRC8

        // Kiểm tra có đủ data cho cả packet không
        if (m_receiveBuffer.size() < totalPacketSize) {
            return; // Chờ thêm data
        }

        // Lấy packet
        QByteArray packet = m_receiveBuffer.left(totalPacketSize);

        // Kiểm tra CRC8 XOR
        quint8 receivedCrc   = static_cast<quint8>(packet.at(totalPacketSize - 1));
        QByteArray pktData   = packet.mid(headerSize, dataLength);
        quint8 calculatedCrc = calc_crc(firstByte, totalMessages, messageIndex, cmd, dataLength, pktData);

        if (calculatedCrc != receivedCrc) {
            m_receiveBuffer.remove(0, 1);
            continue;
        }
        
        // Packet hợp lệ, xử lý
        QByteArray data = packet.mid(headerSize, dataLength); // Bỏ qua header, chỉ lấy data
        
        // Tạo hex dump của toàn bộ packet để log
        QString hexDump;
        for (int i = 0; i < packet.size(); i++) {
            quint8 byte = static_cast<quint8>(packet.at(i));
            hexDump += QString("%1 ").arg(byte, 2, 16, QChar('0')).toUpper();
        }
        
        // Parse data và emit signal
        QVariantMap measurementData;
        measurementData["cmd"] = cmd;
        measurementData["messageIndex"] = messageIndex;
        measurementData["totalMessages"] = totalMessages;
        measurementData["timestamp"] = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");
        measurementData["hexDump"] = hexDump.trimmed(); // Hex dump của toàn bộ packet
        measurementData["packetSize"] = packet.size();
        
        // Parse data: format data là portByte(1) + pinA(1) + pinB(1) + ... hoặc portByte(1) + pin pairs
        // Kiểm tra xem có nhiều portByte không (0xAA, 0xAB, 0xBB)
        int portByteCount = 0;
        for (int i = 0; i < dataLength; i++) {
            quint8 b = static_cast<quint8>(data.at(i));
            if (b == 0xAA || b == 0xAB || b == 0xBB) {
                portByteCount++;
            }
        }
        
        // Nếu có nhiều hơn 1 portByte thì parse nhiều nhóm
        bool hasMultiplePortBytes = (portByteCount > 1);
        
        if (hasMultiplePortBytes) {
            // Parse nhiều portByte cho packet có nhiều nhóm
            QVariantList portByteGroups;
            
            int offset = 0;
            while (offset < dataLength) {
                if (offset >= dataLength) break;
                
                quint8 portByte = static_cast<quint8>(data.at(offset));
                // Kiểm tra xem có phải portByte hợp lệ không
                if (portByte != 0xAA && portByte != 0xAB && portByte != 0xBB) {
                    // Không phải portByte hợp lệ, có thể là dữ liệu pin, bỏ qua
                    offset++;
                    continue;
                }
                
                offset++; // Bỏ qua portByte
                
                // Parse các cặp pin cho portByte này
                QVariantList pinPairs;
                while (offset + 1 <= dataLength) {
                    // Kiểm tra xem có đủ 2 byte để tạo thành 1 cặp pin không
                    if (offset + 1 > dataLength) break;
                    
                    // Kiểm tra xem byte tiếp theo có phải là portByte mới không (0xAA, 0xAB, hoặc 0xBB)
                    // Chỉ kiểm tra nếu đã có ít nhất 1 cặp pin để tránh nhầm lẫn với giá trị pin hợp lệ
                    if (pinPairs.size() > 0 && offset < dataLength) {
                        quint8 nextByte = static_cast<quint8>(data.at(offset));
                        // Nếu byte tiếp theo là portByte hợp lệ và còn đủ chỗ cho ít nhất 1 cặp pin sau đó
                        // thì có thể đây là portByte mới
                        if ((nextByte == 0xAA || nextByte == 0xAB || nextByte == 0xBB) && offset + 3 <= dataLength) {
                            // Kiểm tra xem có phải portByte mới không bằng cách xem byte sau đó có hợp lý không
                            // (ví dụ: nếu là portByte mới thì sẽ có ít nhất 1 cặp pin sau đó)
                            // Nhưng để đơn giản, cứ coi là portByte mới nếu đã có ít nhất 1 cặp pin
                            break; // Dừng lại để xử lý portByte mới
                        }
                    }
                    
                    // Lấy cặp pin
                    quint8 pinA = static_cast<quint8>(data.at(offset));
                    offset++;
                    if (offset >= dataLength) break;
                    
                    quint8 pinB = static_cast<quint8>(data.at(offset));
                    offset++;
                    
                    QVariantMap pair;
                    pair["pinA"] = pinA;
                    pair["pinB"] = pinB;
                    pinPairs.append(pair);
                }
                
                // Lưu nhóm portByte với các cặp pin
                QVariantMap group;
                group["portByte"] = portByte;
                group["pinPairs"] = pinPairs;
                group["numPairs"] = pinPairs.size();
                portByteGroups.append(group);
            }
            
            measurementData["portByteGroups"] = portByteGroups;
            measurementData["numPortByteGroups"] = portByteGroups.size();
            
            // Giữ lại portByte đầu tiên và cặp pin đầu tiên để tương thích với code cũ
            if (portByteGroups.size() > 0) {
                QVariantMap firstGroup = portByteGroups[0].toMap();
                measurementData["portByte"] = firstGroup["portByte"];
                QVariantList firstPinPairs = firstGroup["pinPairs"].toList();
                if (firstPinPairs.size() > 0) {
                    QVariantMap firstPair = firstPinPairs[0].toMap();
                    measurementData["pinA"] = firstPair["pinA"];
                    measurementData["pinB"] = firstPair["pinB"];
                }
            }
        } else {
            // Parse bình thường: chỉ lấy portByte đầu tiên và các cặp pin của nó
            if (dataLength >= 1) {
                quint8 portByte = static_cast<quint8>(data.at(0));
                measurementData["portByte"] = portByte;
                
                // Parse các cặp pin từ data (bỏ qua portByte đầu tiên)
                QVariantList pinPairs;
                int numPairs = (dataLength - 1) / 2; // Trừ portByte, chia 2 để lấy số cặp
                
                for (int i = 0; i < numPairs; i++) {
                    int offset = 1 + i * 2; // Bỏ qua portByte
                    if (offset + 1 < dataLength) {
                        quint8 pinA = static_cast<quint8>(data.at(offset));
                        quint8 pinB = static_cast<quint8>(data.at(offset + 1));
                        QVariantMap pair;
                        pair["pinA"] = pinA;
                        pair["pinB"] = pinB;
                        pinPairs.append(pair);
                    }
                }
                
                measurementData["pinPairs"] = pinPairs;
                measurementData["numPairs"] = pinPairs.size();
                
                // Giữ lại cặp pin đầu tiên để tương thích với code cũ
                if (pinPairs.size() > 0) {
                    QVariantMap firstPair = pinPairs[0].toMap();
                    measurementData["pinA"] = firstPair["pinA"];
                    measurementData["pinB"] = firstPair["pinB"];
                }
            }
        }
        
        // qDebug() << QString(">>> Packet hop le: %1/%2, cmd=0x%3, portByte=0x%4, dataLength=%5, buffer con lai: %6 bytes")
        //             .arg(messageIndex).arg(totalMessages).arg(cmd, 2, 16, QChar('0'))
        //             .arg(measurementData.value("portByte").toInt(), 2, 16, QChar('0')).arg(dataLength)
        //             .arg(m_receiveBuffer.size() - totalPacketSize);
        
        // Emit signal để QML xử lý
        emit dataReceived(measurementData);
        
        // Xóa packet đã xử lý khỏi buffer
        m_receiveBuffer.remove(0, totalPacketSize);
        
        // Tiếp tục parse packet tiếp theo trong buffer (nếu còn)
    }
    
    if (packetsProcessed >= maxIterations) {
        // qDebug() << QString("WARNING: Dat gioi han so lan lap (%1), buffer con lai: %2 bytes").arg(maxIterations).arg(m_receiveBuffer.size());
    }
}

bool McuSender::sendTestPacket()
{
    if (!m_serial.isOpen()) {
        emit errorOccurred(tr("Cổng COM chưa mở. Vui lòng mở cổng COM trước khi gửi bản tin test."));
        return false;
    }
    
    const quint8 startByte = 0x7A;
    const quint8 cmd = 0x8E; // wire_resistance
    const quint8 totalMessages = 1;
    const quint8 messageIndex = 1;
    
    // Tạo data chứa cả 2 portByte và các cặp pin của chúng trong cùng 1 packet
    QByteArray data;
    
    // PortByte AB: 1,1,2,2,3,3,4,4...16,16
    data.append(static_cast<char>(0xAB)); // portByte AB
    for (int i = 1; i <= 16; i++) {
        data.append(static_cast<char>(i));
        data.append(static_cast<char>(i));
    }
    
    // PortByte AA: 1,3,2,4,3,5,4,6...14,16
    data.append(static_cast<char>(0xAA)); // portByte AA
    for (int i = 1; i <= 14; i++) {
        data.append(static_cast<char>(i));
        data.append(static_cast<char>(i + 2));
    }
    
    const quint8 dataLength = static_cast<quint8>(data.size());
    
    // Tạo payload: startByte + totalMessages + messageIndex + cmd + dataLength + data
    QByteArray payload;
    payload.append(static_cast<char>(startByte));
    payload.append(static_cast<char>(totalMessages));
    payload.append(static_cast<char>(messageIndex));
    payload.append(static_cast<char>(cmd));
    payload.append(static_cast<char>(dataLength));
    payload.append(data);
    
    // Tính CRC8
    quint8 crc = calc_crc(startByte, totalMessages, messageIndex, cmd, dataLength, data);
    payload.append(static_cast<char>(crc));

    // Hex dump
    QString hexDump;
    for (int i = 0; i < payload.size(); i++) {
        quint8 byte = static_cast<quint8>(payload.at(i));
        hexDump += QString("%1 ").arg(byte, 2, 16, QChar('0')).toUpper();
    }
    
    qDebug() << QString("[TEST Packet] portByte=0xAB+0xAA, cmd=0x%1, dataLength=%2, %3 bytes")
                .arg(cmd, 2, 16, QChar('0')).arg(dataLength).arg(payload.size());
    qDebug() << QString(">>> GUI TEST PACKET (%1 bytes): %2").arg(payload.size()).arg(hexDump.trimmed());
    
    // Lưu gói vừa gửi
    m_lastSentPacket = payload;

    // Gửi packet
        qint64 written = m_serial.write(payload);
        m_serial.flush();
    
        if (written != payload.size()) {
        emit errorOccurred(tr("Lỗi gửi test packet: chỉ gửi được %1/%2 byte").arg(written).arg(payload.size()));
            return false;
        }
        

    qDebug() << QString(">>> Da gui test packet thanh cong");
    return true;
}

void McuSender::debugHexPacket(const QString &hexString)
{
    // Parse hex string thành QByteArray
    QStringList hexBytes = hexString.split(" ", Qt::SkipEmptyParts);
    QByteArray packet;
    for (const QString &hexByte : hexBytes) {
        bool ok;
        quint8 byte = hexByte.toUInt(&ok, 16);
        if (ok) {
            packet.append(static_cast<char>(byte));
        }
    }
    
    if (packet.size() < 9) {
        qDebug() << "[DEBUG HEX] Packet quá ngắn, cần ít nhất 9 bytes";
        return;
    }
    
    // Parse header
    quint8 startByte = static_cast<quint8>(packet.at(0));
    quint8 totalMessages = static_cast<quint8>(packet.at(1));
    quint8 messageIndex = static_cast<quint8>(packet.at(2));
    quint8 cmd = static_cast<quint8>(packet.at(3));
    quint8 dataLength = static_cast<quint8>(packet.at(4));
    
    QString cmdName;
    if (cmd == 0x8E) cmdName = "continuity";
    else if (cmd == 0x8F) cmdName = "sheath_insulation";
    else if (cmd == 0x8B) cmdName = "calibration";
    else cmdName = "unknown";
    
    qDebug() << "========================================";
    qDebug() << "[DEBUG HEX] PHAN TICH PACKET:";
    qDebug() << "  Kích thước tổng:", packet.size(), "bytes";
    qDebug() << "  Header (5 bytes):";
    qDebug() << "    [0] startByte: 0x" << QString("%1").arg(startByte, 2, 16, QChar('0')).toUpper();
    qDebug() << "    [1] totalMessages:" << totalMessages;
    qDebug() << "    [2] messageIndex:" << messageIndex;
    qDebug() << "    [3] cmd: 0x" << QString("%1").arg(cmd, 2, 16, QChar('0')).toUpper() << "(" << cmdName << ")";
    qDebug() << "    [4] dataLength:" << dataLength << "bytes";
    
    // Parse data
    if (packet.size() < 5 + dataLength + 4) {
        qDebug() << "[DEBUG HEX] Packet không đủ dài cho dataLength và CRC";
        return;
    }
    
    QByteArray data = packet.mid(5, dataLength);
    QByteArray crcBytes = packet.right(1);
    
    qDebug() << "  Data (" << dataLength << "bytes):";
    
    // Kiểm tra có phải test packet không (có nhiều portByte)
    int portByteCount = 0;
    for (int i = 0; i < data.size(); i++) {
        quint8 b = static_cast<quint8>(data.at(i));
        if (b == 0xAA || b == 0xAB) {
            portByteCount++;
        }
    }
    
    bool isTestPacket = (portByteCount == 2);
    
    if (isTestPacket) {
        qDebug() << "    -> Test packet (có 2 portByte)";
        
        int offset = 0;
        int groupIndex = 0;
        while (offset < data.size()) {
            if (offset >= data.size()) break;
            
            quint8 portByte = static_cast<quint8>(data.at(offset));
            offset++;
            
            qDebug() << "    PortByte group" << (groupIndex + 1) << ": 0x" << QString("%1").arg(portByte, 2, 16, QChar('0')).toUpper();
            
            QList<QPair<quint8, quint8>> pinPairs;
            while (offset + 1 <= data.size()) {
                if (offset + 1 > data.size()) break;
                
                // Kiểm tra xem byte tiếp theo có phải portByte mới không
                if (pinPairs.size() > 0 && offset < data.size()) {
                    quint8 nextByte = static_cast<quint8>(data.at(offset));
                    if ((nextByte == 0xAA || nextByte == 0xAB) && offset + 3 <= data.size()) {
                        break;
                    }
                }
                
                quint8 pinA = static_cast<quint8>(data.at(offset));
                offset++;
                if (offset >= data.size()) break;
                
                quint8 pinB = static_cast<quint8>(data.at(offset));
                offset++;
                
                pinPairs.append(qMakePair(pinA, pinB));
            }
            
            qDebug() << "      Số cặp pin:" << pinPairs.size();
            QString pairsStr;
            for (int i = 0; i < qMin(pinPairs.size(), 10); i++) {
                if (i > 0) pairsStr += ", ";
                pairsStr += QString("(%1,%2)").arg(pinPairs[i].first).arg(pinPairs[i].second);
            }
            if (pinPairs.size() > 10) pairsStr += "...";
            qDebug() << "      Các cặp pin:" << pairsStr;
            
            groupIndex++;
        }
    } else {
        // Parse bình thường
        if (data.size() >= 1) {
            quint8 portByte = static_cast<quint8>(data.at(0));
            qDebug() << "    PortByte: 0x" << QString("%1").arg(portByte, 2, 16, QChar('0')).toUpper();
            
            int numPairs = (data.size() - 1) / 2;
            qDebug() << "    Số cặp pin:" << numPairs;
            
            QString pairsStr;
            for (int i = 0; i < qMin(numPairs, 10); i++) {
                int offset = 1 + i * 2;
                if (offset + 1 < data.size()) {
                    quint8 pinA = static_cast<quint8>(data.at(offset));
                    quint8 pinB = static_cast<quint8>(data.at(offset + 1));
                    if (i > 0) pairsStr += ", ";
                    pairsStr += QString("(%1,%2)").arg(pinA).arg(pinB);
                }
            }
            if (numPairs > 10) pairsStr += "...";
            qDebug() << "    Các cặp pin:" << pairsStr;
        }
    }
    
    // Parse CRC8
    quint8 receivedCrc   = static_cast<quint8>(crcBytes.at(0));
    quint8 calculatedCrc = calc_crc(startByte, totalMessages, messageIndex, cmd, dataLength, data);

    qDebug() << "  CRC8 (1 byte):";
    qDebug() << "    Received:   0x" << QString("%1").arg(receivedCrc,   2, 16, QChar('0')).toUpper();
    qDebug() << "    Calculated: 0x" << QString("%1").arg(calculatedCrc, 2, 16, QChar('0')).toUpper();
    if (receivedCrc == calculatedCrc) {
        qDebug() << "    -> CRC HỢP LỆ ✓";
    } else {
        qDebug() << "    -> CRC KHÔNG KHỚP ✗";
    }
    
    qDebug() << "========================================";
}






