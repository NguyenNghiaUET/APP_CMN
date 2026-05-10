#include "TestPlanManager.h"
#include <QFile>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QDebug>
#include <QTimer>
#include <QtConcurrent/QtConcurrentRun>

static QVariant jsonValueToVariant(const QJsonValue &v);
static QJsonValue variantToJsonValue(const QVariant &v);
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Lưu/Load/Xóa file JSON chứa scripts,expose API cho QML(saveSripts, loadScripts, deletePlan, ListPlans)

// Helper: Chuyển QJsonValue → QVariant (đệ quy)
// Dùng khi đọc file JSON → chuyển thành kiểu dữ liệu QML hiểu được
// QJsonObject → QVariantMap, QJsonArray → QVariantList, v.v.
QVariant jsonValueToVariant(const QJsonValue &v)
{
    if (v.isNull() || v.isUndefined())
        return QVariant();
    if (v.isBool()) return v.toBool();
    if (v.isDouble()) return v.toDouble();
    if (v.isString()) return v.toString();
    if (v.isArray()) {
        QVariantList list;
        const QJsonArray arr = v.toArray();
        list.reserve(arr.size());
        for (const QJsonValue &e : arr)
            list.append(jsonValueToVariant(e));
        return list;
    }
    if (v.isObject()) {
        QVariantMap map;
        const QJsonObject obj = v.toObject();
        for (auto it = obj.begin(); it != obj.end(); ++it)
            map.insert(it.key(), jsonValueToVariant(it.value()));
        return map;
    }
    return QVariant();
}

// Helper: Chuyển QVariant → QJsonValue (đệ quy, chiều ngược lại)
// Dùng khi lưu dữ liệu từ QML xuống file JSON
// QVariantMap → QJsonObject, QVariantList → QJsonArray, v.v.
QJsonValue variantToJsonValue(const QVariant &v)
{
    if (!v.isValid() || v.isNull())
        return QJsonValue(QJsonValue::Null);

    if (v.typeId() == QMetaType::Bool)
        return QJsonValue(v.toBool());
    if (v.typeId() == QMetaType::QString)
        return QJsonValue(v.toString());
    if (v.typeId() == QMetaType::Int || v.typeId() == QMetaType::LongLong
        || v.typeId() == QMetaType::UInt || v.typeId() == QMetaType::ULongLong) {
        return QJsonValue(v.toDouble());
    }
    if (v.canConvert<double>())
        return QJsonValue(v.toDouble());
    if (v.canConvert<QVariantList>()) {
        QJsonArray arr;
        const QVariantList lst = v.toList();
        for (const QVariant &e : lst)
            arr.append(variantToJsonValue(e));
        return QJsonValue(arr);
    }
    if (v.canConvert<QVariantMap>()) {
        QJsonObject obj;
        const QVariantMap map = v.toMap();
        for (auto it = map.begin(); it != map.end(); ++it)
            obj.insert(it.key(), variantToJsonValue(it.value()));
        return QJsonValue(obj);
    }
    if (v.canConvert<QString>())
        return QJsonValue(v.toString());
    return QJsonValue(QJsonValue::Null);
}

// Constructor — không đọc file ngay để tránh crash lúc khởi động
// File sẽ được load lần đầu khi QML gọi planNames() / loadScripts() / saveTestPlan()
// (lazy loading pattern)
TestPlanManager::TestPlanManager(QObject *parent) : QObject(parent)
{
}

// Trả về đường dẫn file lưu trữ bài đo: [AppData]/test_plans.json
// Tự tạo thư mục nếu chưa có
QString TestPlanManager::testPlansFilePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty())
        dir = QDir::currentPath();
    if (!QDir().mkpath(dir))
        return QString();
    return dir + QStringLiteral("/test_plans.json");
}

// Đọc file test_plans.json → parse JSON → lưu vào m_plans (QMap<QString, QVariant>)
// m_plans["Bài đo ABC"] = QVariantList chứa các script objects
// Gọi 1 lần duy nhất (lazy load), sau đó dùng cache trong RAM
void TestPlanManager::loadFromFile() const
{
    m_plans.clear();
    const QString path = testPlansFilePath();
    if (path.isEmpty())
        return;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;
    QByteArray data = f.readAll();
    f.close();
    if (data.isEmpty())
        return;
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qDebug() << "[TestPlanManager] load error:" << err.errorString();
        return;
    }
    QJsonObject root = doc.object();
    QJsonObject plansObj = root.value(QStringLiteral("plans")).toObject();
    for (auto it = plansObj.begin(); it != plansObj.end(); ++it) {
        QJsonArray arr = it.value().toArray();
        QVariantList list;
        for (const QJsonValue &val : arr)
            list.append(jsonValueToVariant(val));
        m_plans.insert(it.key(), list);
    }
}

// Ghi toàn bộ m_plans xuống file test_plans.json (đồng bộ)
// Format: { "plans": { "Bài đo A": [...scripts], "Bài đo B": [...scripts] } }
void TestPlanManager::saveToFile()
{
    const QString path = testPlansFilePath();
    if (path.isEmpty())
        return;
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qDebug() << "[TestPlanManager] save error: cannot write" << path;
        return;
    }
    QJsonObject root;
    QJsonObject plansObj;
    for (auto it = m_plans.begin(); it != m_plans.end(); ++it)
        plansObj.insert(it.key(), variantToJsonValue(it.value()));
    root.insert(QStringLiteral("plans"), plansObj);
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    f.close();
}

// [QML API] Trả về danh sách tên tất cả bài đo đã lưu
// VD: ["Bài đo cáp A", "Bài đo cáp B", ...]
// Gọi từ TestPlanListDialog.qml để hiện danh sách
QStringList TestPlanManager::planNames() const
{
    if (!m_loaded) {
        m_loaded = true;
        loadFromFile();
        qDebug() << "[TestPlanManager] planNames() loaded from:" << testPlansFilePath() << "plans count:" << m_plans.size();
    }
    qDebug() << "[TestPlanManager] planNames() returning:" << m_plans.keys();
    return m_plans.keys();
}

// [QML API] Load danh sách scripts của 1 bài đo theo tên
// Trả về QVariantList — mỗi phần tử là 1 script {scriptType, displayText, portPinA, portPinB, ...}
// Gọi từ MainContent.qml khi user chọn bài đo, hoặc CalibrationDialog khi cần quét scripts
QVariantList TestPlanManager::loadScripts(const QString &planName) const
{
    if (!m_loaded) {
        m_loaded = true;
        loadFromFile();
    }
    if (!m_plans.contains(planName))
        return QVariantList();
    QVariant v = m_plans.value(planName);
    if (!v.canConvert<QVariantList>())
        return QVariantList();
    return v.toList();
}

// [QML API] Lưu/cập nhật 1 bài đo
// Input: planName = tên bài đo, scriptsJson = JSON string chứa mảng scripts
// Quy trình:
//   1. Parse scriptsJson → QVariantList
//   2. Lưu vào m_plans[planName]
//   3. Serialize toàn bộ m_plans → JSON
//   4. Ghi file BẤT ĐỒNG BỘ (QtConcurrent::run) để không block UI
//   5. Emit testPlansChanged() để QML biết cập nhật
// Gọi từ AutoTestPlanDialog.qml khi user bấm "Lưu bài đo"
bool TestPlanManager::saveTestPlan(const QString &planName, const QString &scriptsJson)
{
    if (planName.isEmpty())
        return false;
    if (!m_loaded) {
        m_loaded = true;
        loadFromFile();
    }
    QVariantList scripts;
    if (!scriptsJson.isEmpty()) {
        const QByteArray utf8 = scriptsJson.toUtf8();
        if (!utf8.isEmpty()) {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(utf8, &err);
            if (err.error == QJsonParseError::NoError && !doc.isNull() && doc.isArray()) {
                const QJsonArray arr = doc.array();
                scripts.reserve(arr.size());
                for (const QJsonValue &val : arr)
                    scripts.append(jsonValueToVariant(val));
            }
        }
    }
    m_plans.insert(planName, scripts);

    // Serialize JSON trước (trên UI thread - nhanh)
    QJsonObject root;
    QJsonObject plansObj;
    for (auto it = m_plans.begin(); it != m_plans.end(); ++it) {
        const QVariant val = it.value();
        if (val.isValid())
            plansObj.insert(it.key(), variantToJsonValue(val));
    }
    root.insert(QStringLiteral("plans"), plansObj);
    QByteArray jsonData = QJsonDocument(root).toJson(QJsonDocument::Indented);

    // Ghi file bất đồng bộ
    const QString path = testPlansFilePath();
    if (!path.isEmpty()) {
        QtConcurrent::run([path, jsonData]() {
            QFile f(path);
            if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                f.write(jsonData);
                f.close();
                qDebug() << "[TestPlanManager] Saved async to" << path;
            } else {
                qDebug() << "[TestPlanManager] save error: cannot write" << path;
            }
        });
    }

    QTimer::singleShot(0, this, [this]() { emit testPlansChanged(); });
    return true;
}

// [QML API] Xóa 1 bài đo theo tên
// Xóa khỏi m_plans → ghi file (đồng bộ) → emit testPlansChanged()
// Gọi từ TestPlanListDialog.qml khi user bấm "Xóa"
void TestPlanManager::removeTestPlan(const QString &planName)
{
    if (!m_loaded) {
        m_loaded = true;
        loadFromFile();
    }
    if (m_plans.remove(planName) > 0) {
        saveToFile();
        QTimer::singleShot(0, this, [this]() { emit testPlansChanged(); });
    }

}

