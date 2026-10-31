#include "AstraLimits.h"
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDateTime>
#include <QFileInfo>
#include <cmath>
#include <windows.h>

AstraLimits::AstraLimits(QObject* parent) : QObject(parent) {
    process_.setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments* args) { args->flags |= CREATE_NO_WINDOW; });
    connect(&process_, &QProcess::readyReadStandardOutput, this, &AstraLimits::receive);
    connect(&process_, &QProcess::readyReadStandardError, this, [this] { process_.readAllStandardError(); });
    connect(&process_, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) { if (busy_) fail(QStringLiteral("Codex недоступен. Проверьте вход в аккаунт.")); });
    connect(&process_, &QProcess::finished, this, [this] { if (busy_) fail(QStringLiteral("Codex завершил соединение. Повторите обновление.")); });
    periodic_.setInterval(60000); connect(&periodic_, &QTimer::timeout, this, &AstraLimits::refresh); periodic_.start();
    timeout_.setSingleShot(true); timeout_.setInterval(25000); connect(&timeout_, &QTimer::timeout, this, [this] { fail(QStringLiteral("Нет ответа Codex. Данные могут быть устаревшими.")); });
    QTimer::singleShot(0, this, &AstraLimits::refresh);
}
AstraLimits::~AstraLimits() { busy_ = false; stop(); }
void AstraLimits::send(const QJsonObject& message) { process_.write(QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n'); }
void AstraLimits::stop() { timeout_.stop(); if (process_.state() != QProcess::NotRunning) { process_.closeWriteChannel(); process_.kill(); process_.waitForFinished(500); } }
void AstraLimits::fail(const QString& error) { busy_ = false; stale_ = true; status_ = error; stop(); emit changed(); }
void AstraLimits::refresh() {
    if (busy_) return;
    const QString path = QCoreApplication::applicationDirPath() + "/limits/AstraLimitsBridge.exe";
    if (!QFileInfo::exists(path)) { fail(QStringLiteral("Откройте Codex и войдите в аккаунт.")); return; }
    busy_ = true; buffer_.clear(); status_ = QStringLiteral("Обновляем лимиты…"); emit changed();
    process_.start(path, QStringList{}); timeout_.start();
}
QVariantList AstraLimits::parseRows(const QJsonObject& result) {
    QJsonObject buckets = result.value("rateLimitsByLimitId").toObject();
    if (buckets.isEmpty() && result.value("rateLimits").isObject()) buckets.insert("codex", result.value("rateLimits"));
    QVariantList rows;
    auto add = [&](const QJsonObject& window, const QString& bucketName, const QString& fallback) {
        if (window.isEmpty()) return;
        const auto used = window.value("usedPercent");
        double remaining = -1;
        if (used.isDouble() && std::isfinite(used.toDouble()) && used.toDouble() >= 0 && used.toDouble() <= 100) remaining = 100 - used.toDouble();
        const int minutes = window.value("windowDurationMins").toInt();
        QString label = fallback;
        if (minutes == 300) label = QStringLiteral("5 часов");
        else if (minutes == 10080) label = QStringLiteral("Неделя");
        else if (minutes > 0) label = minutes % 60 == 0 ? QString::number(minutes / 60) + QStringLiteral(" ч") : QString::number(minutes) + QStringLiteral(" мин");
        const auto reset = window.value("resetsAt");
        const double resetMs = reset.isDouble() && std::isfinite(reset.toDouble()) && reset.toDouble() > 0 && reset.toDouble() < 32503680000.0 ? reset.toDouble() * 1000.0 : 0;
        rows.append(QVariantMap{{"label",label},{"bucket",bucketName},{"remaining",remaining},{"resetMs",resetMs}});
    };
    QStringList keys = buckets.keys(); if (keys.removeOne("codex")) keys.prepend("codex");
    for (const QString& key : keys) {
        const QJsonObject bucket = buckets.value(key).toObject();
        const QString name = buckets.size() > 1 ? bucket.value("limitName").toString(key) : QString();
        add(bucket.value("primary").toObject(), name, QStringLiteral("Основной"));
        add(bucket.value("secondary").toObject(), name, QStringLiteral("Дополнительный"));
        add(bucket.value("individualLimit").toObject(), name, QStringLiteral("Индивидуальный"));
    }
    return rows;
}
void AstraLimits::receive() {
    buffer_ += process_.readAllStandardOutput();
    if (buffer_.size() > 1024 * 1024) { fail(QStringLiteral("Ответ Codex слишком большой.")); return; }
    while (busy_ && buffer_.contains('\n')) {
        const int end = buffer_.indexOf('\n'); const auto line = buffer_.left(end); buffer_.remove(0,end+1);
        const auto msg = QJsonDocument::fromJson(line).object();
        const int id = msg.value("id").toInt(-1);
        if (id != 1 && id != 2) continue;
        if (msg.contains("error")) { fail(QStringLiteral("Не удалось прочитать лимиты. Проверьте вход в Codex.")); return; }
        if (id == 1) { send({{"method","initialized"},{"params",QJsonObject{}}}); send({{"id",2},{"method","account/rateLimits/read"}}); }
        else {
            const auto result = msg.value("result").toObject(); rows_ = parseRows(result);
            plan_ = result.value("rateLimits").toObject().value("planType").toString().toUpper();
            busy_ = false; stale_ = false;
            status_ = rows_.isEmpty() ? QStringLiteral("Нет доступных данных о лимитах") : QStringLiteral("Обновлено в ") + QTime::currentTime().toString("HH:mm");
            stop(); emit changed(); return;
        }
    }
}
