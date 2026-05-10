#pragma once

#include <QObject>
#include <QTimer>
#include <QQueue>

class ScpiTcpClient;

class MrSeriesController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected     READ isConnected   NOTIFY connectedChanged)
    Q_PROPERTY(double setVoltage  READ setVoltage    WRITE setSetVoltage  NOTIFY setVoltageChanged)
    Q_PROPERTY(double setCurrent  READ setCurrent    WRITE setSetCurrent  NOTIFY setCurrentChanged)
    Q_PROPERTY(double setOCP      READ setOCP        WRITE setSetOCP      NOTIFY setOCPChanged)
    Q_PROPERTY(bool outputEnabled READ outputEnabled NOTIFY outputEnabledChanged)
    Q_PROPERTY(double measVoltage READ measVoltage   NOTIFY measVoltageChanged)
    Q_PROPERTY(double measCurrent READ measCurrent   NOTIFY measCurrentChanged)
    Q_PROPERTY(double measPower   READ measPower     NOTIFY measPowerChanged)

public:
    explicit MrSeriesController(QObject *parent = nullptr);

    Q_INVOKABLE void connectDevice(const QString &host, int port = 5025);
    Q_INVOKABLE void disconnectDevice();
    Q_INVOKABLE void applySettings();
    Q_INVOKABLE void setOutput(bool enabled);

    bool isConnected() const;

    double setVoltage() const  { return m_setVoltage; }
    void   setSetVoltage(double v);
    double setCurrent() const  { return m_setCurrent; }
    void   setSetCurrent(double a);
    double setOCP() const      { return m_setOCP; }
    void   setSetOCP(double a);
    bool   outputEnabled() const { return m_outputEnabled; }

    double measVoltage() const { return m_measVoltage; }
    double measCurrent() const { return m_measCurrent; }
    double measPower()   const { return m_measPower; }

signals:
    void connectedChanged(bool c);
    void setVoltageChanged();
    void setCurrentChanged();
    void setOCPChanged();
    void outputEnabledChanged();
    void measVoltageChanged();
    void measCurrentChanged();
    void measPowerChanged();
    void logMessage(const QString &msg);

private slots:
    void onQueryResult(const QString &result);
    void onPollTick();

private:
    enum PollStep { POLL_VOLT, POLL_CURR, POLL_POW };

    ScpiTcpClient *m_client;
    QTimer        *m_pollTimer;
    PollStep       m_pollStep = POLL_VOLT;
    bool           m_pollActive = false;

    double m_setVoltage    = 28.0;
    double m_setCurrent    = 10.0;
    double m_setOCP        = 11.0;
    bool   m_outputEnabled = false;

    double m_measVoltage = 0.0;
    double m_measCurrent = 0.0;
    double m_measPower   = 0.0;
};
