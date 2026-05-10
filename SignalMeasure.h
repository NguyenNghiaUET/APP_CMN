#pragma once

#include <QObject>
#include <QSerialPort>
#include <QVariantMap>
#include <QStringList>
#include <QTimer>

/*
 * Đọc điện áp 16 tín hiệu từ DUT qua Controller Box (Serial/USB).
 * Packet format: 0xAA + 2-byte LE len + JSON + CRC32 BE.
 *
 * Start: gửi {"cmd":"START_MEASURE"}
 * MCU trả về: {"type":"MEASURE","signals":{"BOOST":3.3,...},"done":bool}
 * Stop:  gửi {"cmd":"STOP_MEASURE"}
 */
class SignalMeasure : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected  READ isConnected  NOTIFY connectedChanged)
    Q_PROPERTY(bool measuring  READ isMeasuring  NOTIFY measuringChanged)
    Q_PROPERTY(QVariantMap signalVoltages READ signalVoltages NOTIFY signalVoltagesChanged)

public:
    static const QStringList kSignalNames; // 16 tên tín hiệu

    explicit SignalMeasure(QObject *parent = nullptr);

    bool isConnected() const;
    bool isMeasuring() const;
    QVariantMap signalVoltages() const { return m_voltages; }

    Q_INVOKABLE void connectPort(const QString &portName, int baud = 115200);
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE void startMeasure();
    Q_INVOKABLE void stopMeasure();

signals:
    void connectedChanged(bool c);
    void measuringChanged(bool m);
    void signalValueUpdated(const QString &name, double voltage);
    void signalVoltagesChanged();
    void measureFinished();
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
    QVariantMap  m_voltages;
};
