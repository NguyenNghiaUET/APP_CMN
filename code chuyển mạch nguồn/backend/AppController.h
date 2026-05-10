#pragma once

#include <QObject>
#include <QStringList>

class MrSeriesController;
class MdlSeriesController;
class ControllerBox;
class SignalMeasure;

class AppController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList logMessages READ logMessages NOTIFY logMessagesChanged)
    Q_PROPERTY(int totalTests READ totalTests NOTIFY statsChanged)
    Q_PROPERTY(int okTests    READ okTests    NOTIFY statsChanged)
    Q_PROPERTY(int ngTests    READ ngTests    NOTIFY statsChanged)
    Q_PROPERTY(double failRate READ failRate  NOTIFY statsChanged)

public:
    explicit AppController(MrSeriesController  *mr,
                           MdlSeriesController *mdl,
                           ControllerBox       *box,
                           SignalMeasure       *sig,
                           QObject *parent = nullptr);

    QStringList logMessages() const { return m_log; }
    int    totalTests() const { return m_total; }
    int    okTests()    const { return m_ok; }
    int    ngTests()    const { return m_ng; }
    double failRate()   const { return m_total > 0 ? (100.0 * m_ng / m_total) : 0.0; }

    Q_INVOKABLE void addResult(bool ok);
    Q_INVOKABLE void clearStats();
    Q_INVOKABLE void clearLog();
    Q_INVOKABLE void addLog(const QString &msg);

signals:
    void logMessagesChanged();
    void statsChanged();

private:
    QStringList          m_log;
    int m_total = 0, m_ok = 0, m_ng = 0;

    static constexpr int kMaxLogLines = 500;
};
