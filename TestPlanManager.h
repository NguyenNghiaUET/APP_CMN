#ifndef TESTPLANMANAGER_H
#define TESTPLANMANAGER_H

#include <QObject>
#include <QStringList>
#include <QVariantList>

class TestPlanManager : public QObject
{
    Q_OBJECT
public:
    explicit TestPlanManager(QObject *parent = nullptr);

    Q_INVOKABLE QStringList planNames() const;
    Q_INVOKABLE QVariantList loadScripts(const QString &planName) const;
    Q_INVOKABLE bool saveTestPlan(const QString &planName, const QString &scriptsJson);
    Q_INVOKABLE void removeTestPlan(const QString &planName);

signals:
    void testPlansChanged();

private:
    QString testPlansFilePath() const;
    void loadFromFile() const;
    void saveToFile();

    mutable bool m_loaded = false;
    mutable QVariantMap m_plans; // planName -> list of script objects
};

#endif // TESTPLANMANAGER_H
