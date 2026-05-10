#include "AppController.h"
#include "MrSeriesController.h"
#include "MdlSeriesController.h"
#include "ControllerBox.h"
#include "SignalMeasure.h"
#include <QDateTime>


AppController::AppController(MrSeriesController  *mr,
                             MdlSeriesController *mdl,
                             ControllerBox       *box,
                             SignalMeasure       *sig,
                             QObject *parent)
    : QObject(parent)
{
    auto fwd = [this](const QString &msg) { addLog(msg); };
    connect(mr,  &MrSeriesController::logMessage,  this, fwd);
    connect(mdl, &MdlSeriesController::logMessage, this, fwd);
    connect(box, &ControllerBox::logMessage,       this, fwd);
    connect(sig, &SignalMeasure::logMessage,        this, fwd);
}

void AppController::addLog(const QString &msg)
{
    const QString line = QStringLiteral("[%1]  %2")
        .arg(QDateTime::currentDateTime().toString("hh:mm:ss.zzz"), msg);
    m_log.prepend(line);
    if (m_log.size() > kMaxLogLines) m_log.removeLast();
    emit logMessagesChanged();
}

void AppController::clearLog()
{
    m_log.clear();
    emit logMessagesChanged();
}



void AppController::addResult(bool ok)
{
    ++m_total;
    if (ok) ++m_ok; else ++m_ng;
    emit statsChanged();
}

void AppController::clearStats()
{
    m_total = m_ok = m_ng = 0;
    emit statsChanged();
}
