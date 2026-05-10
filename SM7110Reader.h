#ifndef SM7110READER_H
#define SM7110READER_H

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QString>

// ⚠️ AN TOÀN ĐIỆN ÁP CAO ⚠️
// SM7110 phóng điện áp DC lên tới 1000V khi đo.
// Sau mỗi phép đo, BẮT BUỘC phải:
//   1. Tắt output (:OUTPut OFF)
//   2. Chờ thời gian xả điện (discharge delay)
// trước khi chạm vào mẫu đo hoặc chuyển relay.

class SM7110Reader : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(bool isOpen READ isOpen NOTIFY openChanged)
    Q_PROPERTY(bool isReading READ isReading NOTIFY readingChanged)
    Q_PROPERTY(int dischargeDelayMs READ dischargeDelayMs WRITE setDischargeDelayMs NOTIFY dischargeDelayMsChanged)

public:
    explicit SM7110Reader(QObject *parent = nullptr);
    ~SM7110Reader();

    QString portName() const { return m_portName; }
    void setPortName(const QString &name);

    bool isOpen() const { return m_serial.isOpen(); }
    bool isReading() const { return m_isReading; }
    int dischargeDelayMs() const { return m_dischargeDelayMs; }
    void setDischargeDelayMs(int ms);

    // Kết nối
    Q_INVOKABLE bool openPort();
    Q_INVOKABLE void closePort();
    
    // Đọc giá trị - dùng :MEASure? (khác RM3544 dùng :READ?)
    Q_INVOKABLE bool readResistance();
    
    // Cấu hình SM7110
    Q_INVOKABLE bool sendCommand(const QString &command);
    Q_INVOKABLE bool setVoltage(int voltage);           // :VOLTage <value>
    Q_INVOKABLE bool setOutput(bool on);                // :OUTPut <ON/OFF>
    Q_INVOKABLE bool setSpeed(const QString &speed);    // :SPEed <FAST/MED/SLOW>
    Q_INVOKABLE bool setCurrentRange(const QString &range); // :CURRent:RANGe <value>
    Q_INVOKABLE bool setCurrentRangeAuto(bool on);      // :CURRent:RANGe:AUTO <ON/OFF>
    
    // DELAY: thời gian chờ trước khi đo (giây) - máy đợi điện trở ổn định
    Q_INVOKABLE bool setTrigDelay(double seconds);      // :TRIG:DEL <time>
    
    // AVG: trung bình n lần đo để giảm nhiễu
    Q_INVOKABLE bool setAverageCount(int count);        // :AVER:COUN <n>
    Q_INVOKABLE bool setAverageEnabled(bool on);        // :AVER <ON/OFF>
    
    // SEQ: chế độ đo liên tục (sequence measurement)
    Q_INVOKABLE bool setSequenceMode(bool on);          // :INIT:CONT <ON/OFF>
    
    Q_INVOKABLE bool configure(int voltage, const QString &speed); // Cấu hình tổng hợp
    // Cấu hình đầy đủ (bao gồm delay, avg, seq)
    Q_INVOKABLE bool configureAdvanced(int voltage, const QString &speed,
                                        double trigDelay, int avgCount, bool avgEnabled);
    
    // ⚠️ AN TOÀN: Xả điện sau khi đo
    // Gửi :OUTPut OFF → chờ dischargeDelayMs → emit dischargeComplete
    Q_INVOKABLE void discharge();

signals:
    void portNameChanged();
    void openChanged();
    void readingChanged();
    void dischargeDelayMsChanged();
    void errorOccurred(const QString &error);
    void resistanceRead(double value); // Giá trị đọc được
    void dischargeComplete();           // ⚠️ Xả điện xong, an toàn để chuyển relay

private slots:
    void onDataReceived();
    void onReadTimeout();
    void onDischargeTimerDone();

private:
    QSerialPort m_serial;
    QString m_portName;
    bool m_isReading;
    QTimer m_readTimeoutTimer;
    QByteArray m_receivedData;
    QTimer m_dischargeTimer;
    int m_dischargeDelayMs = 1000; // Mặc định 1 giây xả điện
 // QByteArray m_1;
    bool parseValue(const QByteArray &data, double &value);
    static const int READ_TIMEOUT_MS = 20000; // 20 giây (SM7110 đo chậm hơn RM3544)
};

#endif // SM7110READER_H
