#include "ControllerBox.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

// --- Static constant lists ---

const QStringList ControllerBox::kPowerRelays = {
    "VLS_ON", "Bat1_ON", "Bat2_ON", "Gen_ON"
};

const QStringList ControllerBox::kCmdRelays = {
    "VLS_BatON", "VLS_BatOFF", "MPSS_TBKT",
    "CMD_ERM", "CMD_PUMP", "CCBH_in",
    "CMD_PPA", "CMD_Pyro1", "CMD_Pyro2",
    "CMD_TJE", "CMD_FUZE"
};

const QStringList ControllerBox::kSignalNames = {
    "BOOST", "FUZE_EN", "FIRE", "SIGNAL_GND",
    "MLD", "TELE", "ERM", "PM77",
    "GEN1_1", "SS1", "PPA", "PYRO",
    "27V_COMMAND", "PYROFLARE_GND", "VALVE_GND"
};

// --- CRC32 STM32 software algorithm (polynomial 0x04C11DB7, no bit-reversal) ---
uint32_t ControllerBox::crc32Stm32(uint32_t crc, const uint8_t *data, size_t len)
{
    for (size_t i = 0; i < len; i++) {
        crc ^= static_cast<uint32_t>(data[i]) << 24;
        for (int bit = 0; bit < 8; bit++) {
            if (crc & 0x80000000u)
                crc = (crc << 1) ^ 0x04C11DB7u;
            else
                crc <<= 1;
        }
    }
    return crc;
}

QByteArray ControllerBox::buildPacket(const QByteArray &json)
{
    const uint16_t len = static_cast<uint16_t>(json.size());
    QByteArray pkt;
    pkt.reserve(3 + len + 4);
    pkt.append(static_cast<char>(0xAA));
    pkt.append(static_cast<char>(len & 0xFF));
    pkt.append(static_cast<char>((len >> 8) & 0xFF));
    pkt.append(json);

    // CRC over entire pkt so far (3 + len bytes)
    const uint32_t crc = crc32Stm32(0xFFFFFFFFu,
                                     reinterpret_cast<const uint8_t *>(pkt.constData()),
                                     static_cast<size_t>(pkt.size()));
    // CRC big-endian
    pkt.append(static_cast<char>((crc >> 24) & 0xFF));
    pkt.append(static_cast<char>((crc >> 16) & 0xFF));
    pkt.append(static_cast<char>((crc >>  8) & 0xFF));
    pkt.append(static_cast<char>( crc        & 0xFF));
    return pkt;
}

// --- Constructor ---
ControllerBox::ControllerBox(QObject *parent)
    : QObject(parent)
    , m_port(new QSerialPort(this))
{
    // Initialize all relay states to false
    for (const auto &r : kPowerRelays)  m_relayStates[r]    = false;
    for (const auto &r : kCmdRelays)    m_relayStates[r]    = false;
    for (const auto &r : kCmdRelays)    m_relayResponses[r] = false;
    for (const auto &s : kSignalNames)  m_signalVoltages[s] = 0.0;

    connect(m_port, &QSerialPort::readyRead, this, &ControllerBox::onReadyRead);
    connect(m_port, &QSerialPort::errorOccurred, this, [this](QSerialPort::SerialPortError e) {
        if (e != QSerialPort::NoError)
            emit logMessage(QStringLiteral("[BOX ERROR] %1").arg(m_port->errorString()));
    });
}

bool ControllerBox::isConnected() const { return m_port->isOpen(); }
bool ControllerBox::isMeasuring() const { return m_measuring; }

void ControllerBox::connectPort(const QString &portName, int baudRate)
{
    if (m_port->isOpen()) m_port->close();
    m_port->setPortName(portName);
    m_port->setBaudRate(baudRate);
    m_port->setDataBits(QSerialPort::Data8);
    m_port->setParity(QSerialPort::NoParity);
    m_port->setStopBits(QSerialPort::OneStop);
    m_port->setFlowControl(QSerialPort::NoFlowControl);

    if (m_port->open(QIODevice::ReadWrite)) {
        emit connectedChanged(true);
        emit logMessage(QStringLiteral("[BOX] Connected to %1").arg(portName));
        requestStatus();
    } else {
        emit logMessage(QStringLiteral("[BOX] Failed to open %1: %2")
                        .arg(portName, m_port->errorString()));
    }
}

void ControllerBox::disconnectPort()
{
    m_port->close();
    m_measuring = false;
    emit connectedChanged(false);
    emit measuringChanged();
    emit logMessage("[BOX] Disconnected.");
}

void ControllerBox::setRelay(const QString &name, bool state)
{
    if (!isConnected()) { emit logMessage("[BOX] Not connected"); return; }
    sendJson({{"cmd", "SET_RELAY"}, {"relay", name}, {"state", state ? 1 : 0}});
    emit logMessage(QStringLiteral("[BOX] SET_RELAY %1 = %2").arg(name).arg(state ? "ON" : "OFF"));
}

void ControllerBox::startMeasure()
{
    if (!isConnected()) return;
    m_measuring = true;
    sendJson({{"cmd", "START_MEASURE"}});
    emit measuringChanged();
    emit logMessage("[BOX] Start measure.");
}

void ControllerBox::stopMeasure()
{
    if (!isConnected()) return;
    m_measuring = false;
    sendJson({{"cmd", "STOP_MEASURE"}});
    emit measuringChanged();
    emit logMessage("[BOX] Stop measure.");
}

void ControllerBox::requestStatus()
{
    if (!isConnected()) return;
    sendJson({{"cmd", "GET_STATUS"}});
}

void ControllerBox::sendJson(const QVariantMap &obj)
{
    const QByteArray json = QJsonDocument(QJsonObject::fromVariantMap(obj)).toJson(QJsonDocument::Compact);
    m_port->write(buildPacket(json));
}

// --- Parse incoming packets ---
void ControllerBox::onReadyRead()
{
    m_rxBuffer += m_port->readAll();

    // Scan for complete packets: 0xAA | len_lo | len_hi | data | CRC32(4)
    while (m_rxBuffer.size() >= 7) {
        // Find 0xAA header
        const int hdr = m_rxBuffer.indexOf(static_cast<char>(0xAA));
        if (hdr < 0) { m_rxBuffer.clear(); break; }
        if (hdr > 0)  m_rxBuffer.remove(0, hdr);

        if (m_rxBuffer.size() < 3) break;

        const uint16_t len = static_cast<uint8_t>(m_rxBuffer[1])
                           | (static_cast<uint8_t>(m_rxBuffer[2]) << 8);
        const int totalSize = 3 + len + 4;
        if (m_rxBuffer.size() < totalSize) break;

        // Verify CRC
        const QByteArray pktHead = m_rxBuffer.left(3 + len);
        const uint32_t crcCalc = crc32Stm32(0xFFFFFFFFu,
                                             reinterpret_cast<const uint8_t *>(pktHead.constData()),
                                             static_cast<size_t>(pktHead.size()));
        const uint32_t crcRecv = (static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+0])) << 24)
                               | (static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+1])) << 16)
                               | (static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+2])) <<  8)
                               |  static_cast<uint32_t>(static_cast<uint8_t>(m_rxBuffer[3+len+3]));

        if (crcCalc == crcRecv) {
            handlePacket(m_rxBuffer.mid(3, len));
        } else {
            emit logMessage(QStringLiteral("[BOX] CRC mismatch — dropping packet"));
        }
        m_rxBuffer.remove(0, totalSize);
    }
}

void ControllerBox::handlePacket(const QByteArray &json)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        emit logMessage(QStringLiteral("[BOX] JSON parse error: %1").arg(err.errorString()));
        return;
    }
    const QJsonObject obj = doc.object();
    const QString type = obj["type"].toString();

    if (type == "STATUS" || type == "MEASURE") {
        // Update relay states
        if (obj.contains("relays")) {
            const QJsonObject relays = obj["relays"].toObject();
            bool changed = false;
            for (auto it = relays.begin(); it != relays.end(); ++it) {
                m_relayStates[it.key()] = it.value().toBool();
                changed = true;
            }
            if (changed) emit relayStatesChanged();
        }
        // Update relay responses
        if (obj.contains("responses")) {
            const QJsonObject resp = obj["responses"].toObject();
            bool changed = false;
            for (auto it = resp.begin(); it != resp.end(); ++it) {
                m_relayResponses[it.key()] = it.value().toBool();
                changed = true;
            }
            if (changed) emit relayResponsesChanged();
        }
        // Update signal voltages
        if (obj.contains("signals")) {
            const QJsonObject sigs = obj["signals"].toObject();
            bool changed = false;
            for (auto it = sigs.begin(); it != sigs.end(); ++it) {
                m_signalVoltages[it.key()] = it.value().toDouble();
                changed = true;
            }
            if (changed) emit signalVoltagesChanged();
        }
    } else if (type == "ACK") {
        emit logMessage(QStringLiteral("[BOX] ACK: %1 ok=%2")
                        .arg(obj["cmd"].toString()).arg(obj["ok"].toInt()));
    }
}


