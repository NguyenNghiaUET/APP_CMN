#ifndef MCUSENDER_H
#define MCUSENDER_H

#include <QObject>
#include <QVariantList>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QTimer>
#include <QStringList>

// Giao tiếp với MCU qua UART (cổng COM / serial port).
// Cấu hình mặc định: 8N1, baud 115200, không flow control.
class McuSender : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)
    Q_PROPERTY(bool isOpen READ isOpen NOTIFY openChanged)
    Q_PROPERTY(int queuedPacketCount READ queuedPacketCount NOTIFY queueChanged)
    Q_PROPERTY(int currentPacketIndex READ currentPacketIndex NOTIFY queueChanged)
    Q_PROPERTY(bool isSendingQueue READ isSendingQueue NOTIFY queueChanged)
    
public:
    explicit McuSender(QObject *parent = nullptr);

    Q_INVOKABLE QStringList getAvailablePorts() const;

    QString portName() const { return m_portName; }
    void setPortName(const QString &name);
    int baudRate() const { return m_baudRate; }
    void setBaudRate(int rate);
    bool isOpen() const;
    
    int queuedPacketCount() const { return m_packetQueue.size(); }
    int currentPacketIndex() const { return m_currentQueueIndex; }
    bool isSendingQueue() const { return m_isSendingQueue; }

    // Gửi danh sách cặp chân xuống MCU.
    Q_INVOKABLE bool sendPinPairs(const QVariantList &pairs);
    
    // Build packet queue từ scripts và gửi packet đầu tiên.
    // Các packet tiếp theo sẽ tự động gửi khi nhận ACK từ MCU.
    // Khi tất cả packets đã gửi và ACK xong → emit allPacketsSent()
    Q_INVOKABLE bool sendTestScripts(const QVariantList &scripts, bool isCalibration = false);
    
    Q_INVOKABLE bool openPort();
    Q_INVOKABLE void closePort();
    
    // Gửi bản tin test fake để test loopback
    Q_INVOKABLE bool sendTestPacket();

    // Debug hex packet
    Q_INVOKABLE void debugHexPacket(const QString &hexString);
    
    // Hủy queue đang gửi
    Q_INVOKABLE void cancelQueue();

    // QML gọi hàm này sau khi đọc máy đo xong → gửi frame tiếp theo
    Q_INVOKABLE void sendNextScript();

signals:
    void portNameChanged();
    void baudRateChanged();
    void openChanged();
    void queueChanged();
    void sent(int count);
    void errorOccurred(const QString &message);
    void dataReceived(const QVariantMap &measurementData);
    // ACK từ MCU (A5 AA SEQ 00 CRC 5A) → QML đọc máy đo rồi gọi sendNextScript()
    void mcuAckReceived();
    // NAK từ MCU (A5 BB SEQ ERR CRC 5A)
    void mcuNakReceived(int errCode);
    void mcuNakSkipped(int seq);   // max retries exhausted, skipped to next packet
    void allPacketsSent();

private slots:
    void onReadyRead();
    void sendNextQueuedPacket();

private:
    void processReceivedData();
    bool sendRawPacket(const QByteArray &packet);

    QByteArray m_receiveBuffer;
    QSerialPort m_serial;
    QString m_portName;
    int m_baudRate = 115200;

    QList<QByteArray> m_packetQueue;
    int m_currentQueueIndex = 0;
    bool m_isSendingQueue = false;

    QByteArray m_lastSentPacket;
    int m_retryCount = 0;
    static const int MAX_RETRIES = 3;

    QTimer m_pollTimer;
};

#endif // MCUSENDER_H
