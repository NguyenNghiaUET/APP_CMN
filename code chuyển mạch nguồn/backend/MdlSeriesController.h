#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVector>

class ScpiTcpClient;

class MdlSeriesController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected       READ isConnected  NOTIFY connectedChanged)
    Q_PROPERTY(QVariantList channelData READ channelData NOTIFY channelDataChanged)

public:
    static constexpr int kNumChannels = 6;

    // Tên nguồn cấp cho từng kênh (cố định theo thiết kế hệ thống)
    static const QStringList kSourceNames; // PUMP, TELE, MLĐ, ERM, PPA, IGNITER

    explicit MdlSeriesController(QObject *parent = nullptr);

    Q_INVOKABLE void connectDevice(const QString &host, int port = 5025);
    Q_INVOKABLE void disconnectDevice();

    Q_INVOKABLE void setChannelCurrent(int ch, double ampere);
    Q_INVOKABLE void setChannelEnabled(int ch, bool enabled);
    Q_INVOKABLE void applyAll();

    bool isConnected() const;
    QVariantList channelData() const;

signals:
    void connectedChanged(bool c);
    void channelDataChanged();
    void loadDataUpdated(int channel, double voltage, double current);
    void logMessage(const QString &msg);

private slots:
    void onQueryResult(const QString &result);
    void onPollTick();

private:
    struct Channel {
        int     index;
        QString name;
        QString source;
        double  setCurrentA  = 0.0;
        double  measCurrentA = 0.0;
        double  measVoltageV = 0.0;
        bool    enabled      = false;
    };

    enum PollStep { STEP_SELECT, STEP_VOLT, STEP_CURR };

    void advancePoll();
    QVariantMap channelToMap(const Channel &ch) const;

    ScpiTcpClient   *m_client;
    QTimer          *m_pollTimer;
    QVector<Channel> m_channels;

    int      m_pollCh     = 0;
    PollStep m_pollStep   = STEP_SELECT;
    bool     m_pollActive = false;
};
