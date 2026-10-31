#include "HardwareTelemetry.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QMessageBox>
#include <QSettings>
#include <QStandardPaths>
#include <cmath>
#include <windows.h>
#include <shellapi.h>

namespace {
quint64 fileTimeValue(const FILETIME& t) {
    return (static_cast<quint64>(t.dwHighDateTime) << 32) | t.dwLowDateTime;
}
QStringList csvColumns(const QString& line) {
    QStringList result;
    QString field;
    bool quote = false;
    for (qsizetype i = 0; i < line.size(); ++i) {
        QChar c = line.at(i);
        if (c == QLatin1Char('"')) {
            if (quote && i + 1 < line.size() && line.at(i + 1) == QLatin1Char('"')) { field += c; ++i; }
            else quote = !quote;
        } else if (c == QLatin1Char(',') && !quote) { result.append(field.trimmed()); field.clear(); }
        else field += c;
    }
    result.append(field.trimmed());
    return quote ? QStringList{} : result;
}
}

HardwareTelemetry::HardwareTelemetry(QObject* parent) : QObject(parent) {
    QSettings cpuInfo(QStringLiteral("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0"), QSettings::NativeFormat);
    cpuName_ = cpuInfo.value("ProcessorNameString", QStringLiteral("Процессор")).toString().simplified();
    wchar_t windowsSystem[MAX_PATH]{};
    if (GetSystemDirectoryW(windowsSystem, MAX_PATH)) {
        smiPath_ = QString::fromWCharArray(windowsSystem) + "/nvidia-smi.exe";
    }
    if (!QFileInfo::exists(smiPath_)) smiPath_ = QStandardPaths::findExecutable("nvidia-smi");
    if (smiPath_.isEmpty()) {
        QString candidate = qEnvironmentVariable("ProgramFiles") + "/NVIDIA Corporation/NVSMI/nvidia-smi.exe";
        if (QFileInfo::exists(candidate)) smiPath_ = candidate;
    }
    gpuProcess_.setProcessChannelMode(QProcess::SeparateChannels);
    gpuProcess_.setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments* args) {
        args->flags |= CREATE_NO_WINDOW;
        args->startupInfo->dwFlags |= STARTF_USESHOWWINDOW;
        args->startupInfo->wShowWindow = SW_HIDE;
    });
    connect(&gpuProcess_, &QProcess::finished, this, &HardwareTelemetry::readGpuResult);
    connect(&gpuProcess_, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            gpuTimeout_.stop();
            gpuUnavailable(QStringLiteral("Датчик видеокарты недоступен"));
        }
    });
    gpuTimeout_.setSingleShot(true);
    gpuTimeout_.setInterval(3500);
    connect(&gpuTimeout_, &QTimer::timeout, this, [this] {
        gpuProcess_.kill();
        gpuUnavailable(QStringLiteral("Датчик видеокарты не ответил"));
    });
    pollTimer_.setInterval(2000);
    connect(&pollTimer_, &QTimer::timeout, this, &HardwareTelemetry::refresh);
    pollTimer_.start();
    updateCpuLoad();
    QTimer::singleShot(0, this, &HardwareTelemetry::refresh);
}

HardwareTelemetry::~HardwareTelemetry() {
    if (gpuProcess_.state() != QProcess::NotRunning) {
        gpuProcess_.kill();
        gpuProcess_.waitForFinished(1000);
    }
}

bool HardwareTelemetry::validTemperature(double value) {
    return std::isfinite(value) && value >= 0 && value <= 125;
}
void HardwareTelemetry::appendHistory(QVariantList& history, double value) {
    if (!validTemperature(value)) return;
    history.append(value);
    while (history.size() > 60) history.removeFirst();
}

void HardwareTelemetry::refresh() {
    updateCpuLoad();
    readCpuSnapshot();
    updatedAt_ = QTime::currentTime().toString("HH:mm:ss");
    emit readingsChanged();
    if (gpuProcess_.state() != QProcess::NotRunning) return;
    if (smiPath_.isEmpty()) {
        gpuUnavailable(QStringLiteral("Драйвер NVIDIA не предоставляет данные"));
        return;
    }
    if (gpuProcess_.isOpen()) {
        gpuProcess_.readAllStandardOutput();
        gpuProcess_.readAllStandardError();
    }
    gpuProcess_.start(smiPath_, {"--query-gpu=name,temperature.gpu,utilization.gpu", "--format=csv,noheader,nounits"}, QIODevice::ReadOnly);
    gpuTimeout_.start();
}

void HardwareTelemetry::gpuUnavailable(const QString& status) {
    gpuTemperature_ = -1;
    gpuLoad_ = -1;
    gpuStatus_ = status;
    emit readingsChanged();
}
void HardwareTelemetry::readGpuResult(int exitCode, QProcess::ExitStatus exitStatus) {
    gpuTimeout_.stop();
    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        gpuUnavailable(QStringLiteral("Датчик видеокарты недоступен"));
        return;
    }
    const QString output = QString::fromUtf8(gpuProcess_.readAllStandardOutput()).trimmed();
    const QStringList first = csvColumns(output.section('\n', 0, 0));
    if (first.size() != 3) { gpuUnavailable(QStringLiteral("Нет данных от видеокарты")); return; }
    bool temperatureOk = false, loadOk = false;
    const double temperature = first[1].toDouble(&temperatureOk), load = first[2].toDouble(&loadOk);
    if (!first[0].isEmpty()) gpuName_ = first[0].left(160);
    gpuTemperature_ = temperatureOk && validTemperature(temperature) ? temperature : -1;
    gpuLoad_ = loadOk && std::isfinite(load) && load >= 0 && load <= 100 ? load : -1;
    gpuStatus_ = gpuTemperature_ >= 0 ? QStringLiteral("Датчик NVIDIA · в реальном времени") : QStringLiteral("Температура не предоставлена драйвером");
    appendHistory(gpuHistory_, gpuTemperature_);
    updatedAt_ = QTime::currentTime().toString("HH:mm:ss");
    emit readingsChanged();
}

void HardwareTelemetry::updateCpuLoad() {
    FILETIME idle{}, kernel{}, user{};
    if (!GetSystemTimes(&idle, &kernel, &user)) { cpuLoad_ = -1; return; }
    quint64 currentIdle = fileTimeValue(idle), currentKernel = fileTimeValue(kernel), currentUser = fileTimeValue(user);
    if (lastKernel_ > 0 && currentKernel >= lastKernel_ && currentUser >= lastUser_ && currentIdle >= lastIdle_) {
        quint64 total = (currentKernel - lastKernel_) + (currentUser - lastUser_);
        quint64 idleDifference = currentIdle - lastIdle_;
        cpuLoad_ = total > 0 && total >= idleDifference ? (total - idleDifference) * 100.0 / total : -1;
    }
    lastIdle_ = currentIdle; lastKernel_ = currentKernel; lastUser_ = currentUser;
}

QString HardwareTelemetry::snapshotPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/Sensors/cpu.json";
}
QString HardwareTelemetry::sensorDirectory() const { return QCoreApplication::applicationDirPath() + "/sensors"; }
bool HardwareTelemetry::pawnIoInstalled() const {
    QSettings pawn(QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\PawnIO"), QSettings::NativeFormat);
    return !pawn.value("DisplayVersion").toString().isEmpty();
}

bool HardwareTelemetry::retainRecentCpuReading() {
    // File.Replace may momentarily deny a reader while publishing a snapshot.
    // A sharing race must not erase a still-fresh, validated hardware reading.
    // Monotonic age plus source timestamp prevents stale values surviving a
    // stopped helper or a Windows wall-clock adjustment.
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (lastCpuTemperature_ < 0 || !cpuReadingAge_.isValid() || cpuReadingAge_.elapsed() > 8000
        || lastCpuTimestamp_ < now - 8000 || lastCpuTimestamp_ > now + 2000) return false;
    cpuTemperature_ = lastCpuTemperature_;
    cpuStatus_ = lastCpuStatus_;
    return true;
}

void HardwareTelemetry::readCpuSnapshot() {
    cpuTemperature_ = -1;
    QFile file(snapshotPath());
    if (!file.open(QIODevice::ReadOnly) || file.size() > 16384) {
        if (retainRecentCpuReading()) return;
        cpuStatus_ = pawnIoInstalled() ? QStringLiteral("Разрешите доступ к датчику CPU") : QStringLiteral("Подключите датчик CPU");
        return;
    }
    QJsonParseError parseError;
    QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        if (retainRecentCpuReading()) return;
        cpuStatus_ = QStringLiteral("Нет свежих данных от CPU"); return;
    }
    const QJsonObject snapshot = document.object();
    const QJsonValue stamp = snapshot.value("timestamp"), value = snapshot.value("cpuTemperature");
    if (snapshot.value("version").toInt() != 1 || !stamp.isDouble()) {
        if (retainRecentCpuReading()) return;
        cpuStatus_ = QStringLiteral("Нет свежих данных от CPU"); return;
    }
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const double timestamp = stamp.toDouble();
    if (!std::isfinite(timestamp) || timestamp < now - 8000.0 || timestamp > now + 2000.0) {
        cpuStatus_ = QStringLiteral("Датчик CPU отключён · подключите снова");
        return;
    }
    const QString name = snapshot.value("cpuName").toString();
    if (!name.isEmpty()) cpuName_ = name.left(160);
    const QString status = snapshot.value("status").toString();
    if (value.isDouble() && validTemperature(value.toDouble()) && status == "ready") {
        cpuTemperature_ = value.toDouble();
        appendHistory(cpuHistory_, cpuTemperature_);
        const QString source = snapshot.value("source").toString();
        cpuStatus_ = source.contains("Package", Qt::CaseInsensitive) ? QStringLiteral("Датчик CPU Package · в реальном времени") : QStringLiteral("Датчик процессора · в реальном времени");
        const qint64 sourceTimestamp = static_cast<qint64>(timestamp);
        if (lastCpuTimestamp_ != sourceTimestamp || !cpuReadingAge_.isValid()) cpuReadingAge_.restart();
        lastCpuTimestamp_ = sourceTimestamp;
        lastCpuTemperature_ = cpuTemperature_;
        lastCpuStatus_ = cpuStatus_;
    } else if (status == "driver_missing") cpuStatus_ = QStringLiteral("Для CPU требуется модуль PawnIO");
    else if (status == "admin_required") cpuStatus_ = QStringLiteral("Разрешите доступ к датчику CPU");
    else cpuStatus_ = QStringLiteral("Датчик CPU пока не передаёт температуру");
}

void HardwareTelemetry::connectCpuSensors() {
    const QString directory = sensorDirectory();
    QString executable;
    QString parameters;
    if (!pawnIoInstalled()) {
        executable = directory + "/PawnIO_setup.exe";
        if (!QFileInfo::exists(executable)) { cpuStatus_ = QStringLiteral("Не найден установщик датчика в папке sensors"); emit readingsChanged(); return; }
        const auto answer = QMessageBox::question(nullptr, QStringLiteral("Датчик температуры CPU"),
            QStringLiteral("Для чтения температуры процессора требуется модуль PawnIO 2.2.0.\n\nОткрыть его официальный установщик? Windows запросит разрешение администратора. После установки нажмите «Подключить датчик CPU» ещё раз."),
            QMessageBox::Yes | QMessageBox::No, QMessageBox::No);
        if (answer != QMessageBox::Yes) return;
        cpuStatus_ = QStringLiteral("После установки подключите датчик ещё раз");
    } else {
        executable = directory + "/ReworkSensorHost.exe";
        parameters = QStringLiteral("--owner %1").arg(QCoreApplication::applicationPid());
        if (!QFileInfo::exists(executable)) { cpuStatus_ = QStringLiteral("Не найден модуль чтения CPU в папке sensors"); emit readingsChanged(); return; }
        cpuStatus_ = QStringLiteral("Ожидание разрешения Windows…");
    }
    const std::wstring exe = QDir::toNativeSeparators(executable).toStdWString();
    const std::wstring args = parameters.toStdWString();
    const std::wstring working = QDir::toNativeSeparators(directory).toStdWString();
    HINSTANCE result = ShellExecuteW(nullptr, L"runas", exe.c_str(), args.empty() ? nullptr : args.c_str(), working.c_str(), pawnIoInstalled() ? SW_HIDE : SW_SHOWNORMAL);
    if (reinterpret_cast<INT_PTR>(result) <= 32) cpuStatus_ = QStringLiteral("Подключение отменено или запрещено Windows");
    emit readingsChanged();
}
