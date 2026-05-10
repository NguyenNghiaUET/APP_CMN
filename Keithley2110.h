#ifndef KEITHLEY2110_H
#define KEITHLEY2110_H

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QString>

// Keithley 2110-220 DMM — giao tiếp qua USB virtual COM (USBTMC), SCPI protocol
class Keithley2110 : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(bool isOpen READ isOpen NOTIFY openChanged)
    Q_PROPERTY(bool isReading READ isReading NOTIFY readingChanged)

public:
    explicit Keithley2110(QObject *parent = nullptr);
    ~Keithley2110();

    QString portName() const { return m_portName; }
    void setPortName(const QString &name);

    bool isOpen() const { return m_serial.isOpen(); }
    bool isReading() const { return m_isReading; }

    Q_INVOKABLE bool openPort();
    Q_INVOKABLE void closePort();
    Q_INVOKABLE bool readResistance();
    Q_INVOKABLE bool sendCommand(const QString &command);
    Q_INVOKABLE bool configureRM3544(const QString &range, const QString &speed);
    Q_INVOKABLE bool configureAverage(int count);

signals:
    void portNameChanged();
    void openChanged();
    void readingChanged();
    void errorOccurred(const QString &error);
    void resistanceRead(double value);

private slots:
    void onDataReceived();
    void onReadTimeout();

private:
    QSerialPort m_serial;
    QString m_portName;
    bool m_isReading;
    QTimer m_readTimeoutTimer;
    QByteArray m_receivedData;

    bool parseNR3(const QByteArray &data, double &value);
    static const int READ_TIMEOUT_MS = 10000;
};

#endif // KEITHLEY2110_H
