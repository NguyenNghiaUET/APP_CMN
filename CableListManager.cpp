#include "CableListManager.h"
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QStringConverter>
#include <QUrl>
#include <QDebug>
#include <QLocale>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#ifdef HAVE_QXLSX
#include <xlsxdocument.h>
#include <xlsxcellrange.h>
#include <xlsxcell.h>
using namespace QXlsx;

#endif

// Chuyển giá trị ô Excel sang chuỗi: số dùng C locale; ô định dạng % (7 trong file = 7%) -> chia 100 thành 0.07.

////Convert value in excel to string
static QString cellValueToString(const QVariant &v, Document *doc, int row, int col)
{
    if (!v.isValid())
        return QString();
    double numVal = 0;
    bool isNum = (v.typeId() == QMetaType::Double || v.typeId() == QMetaType::Float
        || v.typeId() == QMetaType::Int || v.typeId() == QMetaType::LongLong
        || v.typeId() == QMetaType::UInt || v.typeId() == QMetaType::ULongLong);
    if (isNum) {
        numVal = v.toDouble();  // chuyển QVariant thành số double
        if (doc) {
            Cell *cell = doc->cellAt(row, col);      // Lấy giá trị tại ô (row,col)
            if (cell && cell->format().numberFormat().contains(QLatin1String("%"))
                && numVal >= 1.0)
                numVal /= 100.0;
        }
        return QLocale::c().toString(numVal, 'g', 15).trimmed();
    }
    if (v.canConvert<QDateTime>())  //chuyển QVariant sang QDateTime
        return v.toDateTime().toString(Qt::ISODate);  // Định dạng ngày tháng năm
    if (v.canConvert<QDate>())   // chuyển QVariant sang QDate
        return v.toDate().toString(Qt::ISODate);    // Định dạng ngày tháng năm
    return v.toString().trimmed();  // Chuyển QVariant sang chuỗi 
}

CableListManager::CableListManager(QObject *parent) : QObject(parent) // nhận tham số parent - đối tượng cha trong hệ thống quản lý bộ nhớ của Qt
{
    // CableListManager(QObject *parent) nhận tham số parent - đối tượng cha trong hệ thống quản lý của bộ nhớ của Qt
    loadCableList();    // đọc danh sách cable đã lưu từ JSON và nạp vào m_paths và m_names
}

QStringList CableListManager::cableNames() const
{
    return m_names;
}

QString CableListManager::cablePath(int index) const
{
    if (index >= 0 && index < m_paths.size())
        return m_paths.at(index);
    return QString();
}

int CableListManager::cableCount() const
{
    return m_paths.size();
}

QString CableListManager::baseNameFromPath(const QString &path)
{
    return QFileInfo(path).completeBaseName();
    // qDebug() << "path:" << path;
}

bool CableListManager::addCableFile(const QString &filePath)
{
    if (filePath.isEmpty())
        return false;
    QString path = filePath.trimmed();
    if (path.startsWith(QLatin1String("file:")))
        path = QUrl(path).toLocalFile();
    if (path.isEmpty() || !QFile::exists(path))
        return false;
    QString name = baseNameFromPath(path);
    if (m_paths.contains(path))
        return false;
    m_paths.append(path);
    m_names.append(name);
    emit cableListChanged();
    saveCableList();
    return true;
}

void CableListManager::removeCableFile(int index)  // 
{
    if (index >= 0 && index < m_paths.size()) {
        m_paths.removeAt(index); 
        m_names.removeAt(index);
        emit cableListChanged();
        saveCableList();
    }
}

QString CableListManager::cableListFilePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);   // lấy đường dẫn chứa file cable_list.json
    QDir().mkpath(dir);  // tạo thư mục nếu chưa có
    return dir + "/cable_list.json"; // trả về đường dẫn file cale_list.json
}

void CableListManager::saveCableList()
{
    // tạo mảng Json chứa danh sách đường dẫn cable
    QJsonArray arr;
    for (const QString &p : m_paths)  // duyệt qua danh sách đường dẫn cable
        arr.append(p);   // thêm đường dẫn vào mảng
    
    QJsonObject obj;
    obj["cables"] = arr;
    
    QFile f(cableListFilePath());
    if (f.open(QIODevice::WriteOnly)) {    // mở chế độ ghi 
        f.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));  // chuyển JSON -> TEXT rồi ghi vào file 
        f.close();
        qDebug() << "[CableListManager] Saved" << m_paths.size() << "cables to" << cableListFilePath();
    } else {
        qDebug() << "[CableListManager] Cannot save cable list to" << cableListFilePath();
    }
}

void CableListManager::loadCableList()
{
    QString path = cableListFilePath();
    QFile f(path);
    if (!f.exists()) {
        qDebug() << "[CableListManager] No saved cable list at" << path;
        return;
    }
    if (!f.open(QIODevice::ReadOnly)) {
        qDebug() << "[CableListManager] Cannot open" << path;
        return;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    
    if (!doc.isObject()) return;
    QJsonArray arr = doc.object().value("cables").toArray();
    
    m_paths.clear();
    m_names.clear();
    
    int loaded = 0, skipped = 0;
    for (int i = 0; i < arr.size(); i++) {
        QString p = arr.at(i).toString();
        if (p.isEmpty()) continue;
        if (!QFile::exists(p)) {
            qDebug() << "[CableListManager] Skip missing file:" << p;
            skipped++;
            continue;
        }
        m_paths.append(p);
        m_names.append(baseNameFromPath(p));
        loaded++;
    }
    
    if (loaded > 0)
        emit cableListChanged();
    
    qDebug() << "[CableListManager] Loaded" << loaded << "cables," << skipped << "skipped (missing)";
}

QVariantList CableListManager::parseCsvFile(const QString &filePath)
{
    QVariantList rows;
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return rows;

    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    bool firstLine = true;
    while (!in.atEnd()) {
        QString line = in.readLine();
        QStringList cells;
        QString cell;
        bool inQuotes = false;
        for (int i = 0; i < line.size(); ++i) {
            QChar c = line.at(i);
            if (c == QChar('"')) {
                inQuotes = !inQuotes;
            } else if (!inQuotes && (c == QChar(',') || c == QChar(';') || c == QChar('\t'))) {
                cells.append(cell.trimmed());
                cell.clear();
            } else {
                cell.append(c);
            }
        }
        cells.append(cell.trimmed());

        if (cells.isEmpty())
            continue;
        // Bỏ qua dòng tiêu đề nếu toàn chữ
        if (firstLine) {
            firstLine = false;
            bool looksLikeHeader = true;
            for (const QString &s : cells) {
                if (s.length() > 0) {
                    bool hasDigit = false;
                    for (const QChar &ch : s)
                        if (ch.isDigit()) { hasDigit = true; break; }
                    if (hasDigit) { looksLikeHeader = false; break; }
                }
            }
            if (looksLikeHeader && cells.count() >= 2)
                continue;
        }

        QVariantMap rowMap;
        for (int i = 0; i < 8; ++i) {
            QString key = QString("col%1").arg(i);
            rowMap[key] = (i < cells.size() ? cells.at(i) : QString());
        }
        rows.append(rowMap);

    }
    return rows;
}

QVariantList CableListManager::parseXlsxFile(const QString &filePath)
{
    QVariantList rows;
#ifdef HAVE_QXLSX
    qDebug() << "[QXlsx] Mở file:" << filePath;

    Document doc(filePath);
    if (!doc.load()) {
        qDebug() << "[QXlsx] file not open";
        return rows;
    }
    qDebug() << "[QXlsx] Load file OK";

    QStringList sheets = doc.sheetNames();
    qDebug() << "[QXlsx] Số sheet:" << sheets.size() << sheets;

    if (!sheets.isEmpty())
        doc.selectSheet(sheets.first());
    else {
        qDebug() << "[QXlsx] Không có sheet nào!";
        return rows;
    }

    const int maxCol = 8;
    int rowStart = 1, rowEnd = 10000;
    bool useDimension = false;
    CellRange dim = doc.dimension();
    if (dim.isValid() && dim.lastRow() >= 1) {
        rowStart = qMax(1, dim.firstRow());
        rowEnd = qMin(10000, dim.lastRow());
        useDimension = true;
        qDebug() << "[QXlsx] Dimension:" << rowStart << "-" << rowEnd << "rows, cols" << dim.firstColumn() << "-" << dim.lastColumn();
    }

    for (int r = rowStart; r <= rowEnd; ++r) {
        QVariantMap rowMap;
        bool hasData = false;
        for (int c = 1; c <= maxCol; ++c) {
            QVariant v = doc.read(r, c);
            QString s = cellValueToString(v, &doc, r, c);
            if (s.isEmpty() && v.isValid())
                s = v.toString().trimmed();
            if (!s.isEmpty())
                hasData = true;
            QString key = QString("col%1").arg(c - 1);
            rowMap[key] = s;
        }
        if (useDimension) {
            rows.append(rowMap);
        } else {
            if (!hasData)
                break;
            rows.append(rowMap);
        }
    }
    qDebug() << "[QXlsx] Đọc được" << rows.size() << "dòng";
#else
    Q_UNUSED(filePath);
#endif
    return rows;
}

QVariantList CableListManager::loadTableData(const QString &filePath)
{
    qDebug() << "[loadTableData] path nhận được:" << filePath;

    if (filePath.isEmpty()) {
        qDebug() << "[loadTableData] path rỗng";
        return QVariantList();

    }
    QString path = filePath.trimmed();
    if (path.startsWith(QLatin1String("file:")))
        path = QUrl(path).toLocalFile();
    qDebug() << "[loadTableData] path sau chuẩn hóa:" << path << "| exists:" << QFile::exists(path);

    if (path.isEmpty() || !QFile::exists(path)) {
        qDebug() << "[loadTableData] File không tồn tại hoặc path rỗng";
        return QVariantList();
    }

    QFileInfo fi(path);
    QString suffix = fi.suffix().toLower();
    qDebug() << "[loadTableData] Đuôi file:" << suffix;

    if (suffix == "csv" || suffix == "txt") {
        auto result = parseCsvFile(path);
        qDebug() << "[loadTableData] CSV trả về" << result.size() << "dòng";
        return result;
    }
    if (suffix == "xlsx" || suffix == "xls") {
#ifdef HAVE_QXLSX
        auto result = parseXlsxFile(path);
        qDebug() << "[loadTableData] XLSX trả về" << result.size() << "dòng";
        return result;
#else
        qDebug() << "[loadTableData] QXlsx chưa có, không đọc được .xlsx/.xls";
        return QVariantList();
#endif
    }
    return parseCsvFile(path);
}








