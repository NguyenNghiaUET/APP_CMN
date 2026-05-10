#include "SignalMeasure.h"
#include <QJsonDocument>
#include <QJsonObject>

const QStringList SignalMeasure::kSignalNames = {
    "BOOST", "FUZE_EN", "FIRE", "SIGNAL_GND",
    "MLD",   "TELE",    "ERM",  "PM77",
    "GEN1_1","SS1",     "PPA",  "PYRO",
    "27V_COMMAND", "PYROFLARE_GND", "VALVE_GND", "RESERVE"
};

uint32_t SignalMeasure::crc32Stm32(uint32_t crc, const uint8_t *data, size_t len)
{
    for (size_t i = 0; i < len; i++) {
        crc ^= static_cast<uint32_t>(data[i]) << 24;
        for (int bit = 0; bit < 8; bit++)
            crc = (crc & 0x80000000u) ? (crc << 1) ^ 0x04C11DB7u : (crc << 1);
    }
    return crc;
}

QByteArray SignalMeasure::buildPacket(const QByteArray &json)
{
    const uint16_t len = static_cast<uint16_t>(json.size());
    QByteArray pkt;
    pkt.reserve(3 + len + 4);
    pkt.append(static_cast<char>(0xAA));
    pkt.append(static_cast<char>(len & 0xFF));
    pkt.append(static_cast<char>((len >> 8) & 0xFF));
    pkt.append(json);
    const uint32_t crc = crc32Stm32(0xFFFFFFFFu,
                                     reinterpret_cast<const uint8_t *>(pkt.constData()),
                                     static_cast<size_t>(pkt.size()));
    pkt.append(static_cast<char>((crc >> 24) & 0xFF));
    pkt.append(static_cast<char>((crc >> 16) & 0xFF));
    pkt.append(static_cast<char>((crc >>  8) & 0xFF));
    pkt.append(static_cast<char>( crc        & 0xFF));
    return pkt;
}

SignalMeasure::SignalMeasure(QObject *parent)
    : QObject(parent)
    , m_port(new QSerialPort(this))
{
    for (const auto &s : kSignalNames) m_voltages[s] = 0.0;

    connect(m_port, &QSerialPort::readyRead, this, &SignalMeasure::onReadyRead);
    connect(m_port, &QSerialPort::errorOccurred, this, [this](QSerialPort::SerialPortError e) {
        if (e != QSerialPort::NoError)
            emit logMessage(QStringLiteral("[SIG ERROR] %1").arg(m_port->errorString()));
    });
}

bool SignalMeasure::isConnected() const { return m_port->isOpen(); }
bool SignalMeasure::isMeasuring()  const { return m_measuring; }

void SignalMeasure::connectPort(const QString &portName, int baud)
{
    if (m_port->isOpen()) m_port->close();
    m_port->setPortName(portName);
    m_port->setBaudRate(baud);
    m_port->setDataBits(QSerialPort::Data8);
    m_port->setParity(QSerialPort::NoParity);
    m_port->setStopBits(QSerialPort::OneStop);
    m_port->setFlowControl(QSerialPort::NoFlowControl);

    if (m_port->open(QIODevice::ReadWrite)) {
        emit connectedChanged(true);
        emit logMessage(QStringLiteral("[SIG] Connected to %1").arg(portName));
    } else {
        emit logMessage(QStringLiteral("[SIG] Cannot open %1: %2").arg(portName, m_port->errorString()));
    }
}

void SignalMeasure::disconnectPort()
{
    if (m_measuring) stopMeasure();
    m_port->close();
    emit connectedChanged(false);
    emit logMessage("[SIG] Disconnected.");
}

void SignalMeasure::startMeasure()
{
    if (!isConnected()) { emit logMessage("[SIG] Not connected"); return; }
    m_measuring = true;
    sendJson({{"cmd", "START_MEASURE"}});
    emit measuringChanged(true);
    emit logMessage("[SIG] Start measure — đọc 16 kênh tín hiệu.");
}

void SignalMeasure::stopMeasure()
{
    if (!isConnected()) return;
    m_measuring = false;
    sendJson({{"cmd", "STOP_MEASURE"}});
    emit measuringChanged(false);
    emit measureFinished();
    emit logMessage("[SIG] Stop measure.");
}

void SignalMeasure::sendJson(const QVariantMap &obj)
{
    const QByteArray json = QJsonDocument(QJsonObject::fromVariantMap(obj))
                                .toJson(QJsonDocument::Compact);
    m_port->write(buildPacket(json));
}

void SignalMeasure::onReadyRead()
{
    m_rxBuffer += m_port->readAll();

    while (m_rxBuffer.size() >= 7) {
        const int hdr = m_rxBuffer.indexOf(static_cast<char>(0xAA));
        if (hdr < 0) { m_rxBuffer.clear(); break; }
        if (hdr > 0)  m_rxBuffer.remove(0, hdr);
        if (m_rxBuffer.size() < 3) break;

        const uint16_t len = static_cast<uint8_t>(m_rxBuffer[1])
                           | (static_cast<uint8_t>(m_rxBuffer[2]) << 8);
        const int total = 3 + len + 4;
        if (m_rxBuffer.size() < total) break;

        const QByteArray head = m_rxBuffer.left(3 + len);
        const uint32_t crcCalc = crc32Stm32(0xFFFFFFFFu,
                                             reinterpret_cast<const uint8_t *>(head.constData()),
                                             static_cast<size_t>(head.size()));
        const uint32_t crcRecv =
              (static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+0])) << 24)
            | (static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+1])) << 16)
            | (static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+2])) <<  8)
            |  static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+3]));

        if (crcCalc == crcRecv)
            handlePacket(m_rxBuffer.mid(3, len));
        else
            emit logMessage("[SIG] CRC mismatch — dropped");

        m_rxBuffer.remove(0, total);
    }
}

void SignalMeasure::handlePacket(const QByteArray &json)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return;

    const QJsonObject obj = doc.object();
    const QString type = obj["type"].toString();

    if (type == "MEASURE" && obj.contains("signals")) {
        const QJsonObject sigs = obj["signals"].toObject();
        bool any = false;
        for (auto it = sigs.begin(); it != sigs.end(); ++it) {
            const double v = it.value().toDouble();
            m_voltages[it.key()] = v;
            emit signalValueUpdated(it.key(), v);
            any = true;
        }
        if (any) emit signalVoltagesChanged();

        if (obj["done"].toBool(false)) {
            m_measuring = false;
            emit measuringChanged(false);
            emit measureFinished();
            emit logMessage("[SIG] Measure finished.");
        }
    }
}
