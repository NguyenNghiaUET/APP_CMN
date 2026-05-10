#pragma once

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QVariantMap>
#include <QByteArray>

/*
 * Protocol: PC → MCU
 *   [0xAA][len_lo][len_hi][JSON...][CRC32 big-endian 4 bytes]
 *   CRC32 covers bytes 0..(3+len-1) inclusive (STM32 sw CRC32 algo)
 *
 * MCU → PC: same framing
 */
class ControllerBox : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected      READ isConnected   NOTIFY connectedChanged)
    Q_PROPERTY(QVariantMap relayStates    READ relayStates    NOTIFY relayStatesChanged)
    Q_PROPERTY(QVariantMap relayResponses READ relayResponses NOTIFY relayResponsesChanged)
    Q_PROPERTY(QVariantMap signalVoltages READ signalVoltages NOTIFY signalVoltagesChanged)
    Q_PROPERTY(bool measuring      READ isMeasuring   NOTIFY measuringChanged)

public:
    // Power relays (toggle)
    static const QStringList kPowerRelays;
    // Command relays (momentary)
    static const QStringList kCmdRelays;
    // DUT signal names
    static const QStringList kSignalNames;

    explicit ControllerBox(QObject *parent = nullptr);

    bool isConnected() const;
    bool isMeasuring() const;


    QVariantMap relayStates()    const { return m_relayStates; }
    QVariantMap relayResponses() const { return m_relayResponses; }
    QVariantMap signalVoltages() const { return m_signalVoltages; }

    Q_INVOKABLE void connectPort(const QString &portName, int baudRate = 115200);
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE void setRelay(const QString &name, bool state);
    Q_INVOKABLE void startMeasure();
    Q_INVOKABLE void stopMeasure();
    Q_INVOKABLE void requestStatus();

signals:
    void connectedChanged(bool c);
    void relayStatesChanged();
    void relayResponsesChanged();
    void signalVoltagesChanged();
    void measuringChanged();
    void logMessage(const QString &msg);

private slots:
    void onReadyRead();

private:
    void sendJson(const QVariantMap &obj);
    void handlePacket(const QByteArray &json);

    static uint32_t crc32Stm32(uint32_t init, const uint8_t *data, size_t len);
    static QByteArray buildPacket(const QByteArray &json);

    QSerialPort *m_port;
    QByteArray   m_rxBuffer;
    bool         m_measuring = false;

    QVariantMap  m_relayStates;
    QVariantMap  m_relayResponses;
    QVariantMap  m_signalVoltages;
};
