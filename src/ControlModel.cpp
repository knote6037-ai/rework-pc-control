#include "ControlModel.h"

#include <QUuid>
#include <algorithm>
#include <stdexcept>
#include <utility>

namespace Rework {

namespace {
std::runtime_error modelError(const QString& message)
{
    return std::runtime_error(message.toUtf8().constData());
}
}

ControlModel::ControlModel(Clock& clock, Shutdown shutdown, bool demo)
    : clock_(clock), shutdown_(std::move(shutdown)), demo_(demo)
{
}

qint64 ControlModel::remainingMs() const
{
    return due_ ? std::max<qint64>(0, *due_ - clock_.monotonicMs()) : 0;
}

int ControlModel::remainingSeconds() const
{
    return static_cast<int>((remainingMs() + 999) / 1000);
}

qint64 ControlModel::deadlineMs() const
{
    // UTC is presentation only. Recompute the displayed deadline after a
    // Windows wall-clock change without changing the elapsed countdown.
    return due_ ? clock_.utcMs() + remainingMs() : 0;
}

double ControlModel::progress() const
{
    return totalSeconds_ > 0 ? std::clamp(remainingMs() / (totalSeconds_ * 1000.0), 0.0, 1.0) : 0.0;
}

void ControlModel::validateMinutes(int minutes)
{
    if (minutes < 1 || minutes > 180)
        throw std::invalid_argument(QStringLiteral("Выберите от 1 до 180 минут.").toUtf8().constData());
}

void ControlModel::setDuration(int minutes)
{
    validateMinutes(minutes);
    if (mode_ == QStringLiteral("shuttingDown")) return;
    // A preference change invalidates a question that described another
    // duration. It never changes an already-confirmed deadline.
    dismiss();
    minutes_ = minutes;
    message_.clear();
}

void ControlModel::prepare(int minutes)
{
    validateMinutes(minutes);
    if (mode_ == QStringLiteral("shuttingDown")) return;
    previousMode_ = due_ ? QStringLiteral("closed") : QStringLiteral("open");
    minutes_ = confirmationMinutes_ = minutes;
    confirmationToken_ = QUuid::createUuid().toString(QUuid::WithoutBraces);
    confirmationExpires_ = clock_.monotonicMs() + 30000;
    message_.clear();
    mode_ = QStringLiteral("pending");
}

void ControlModel::restoreCountdown(qint64 utcDeadline, int originalTotalSeconds)
{
    const qint64 now = clock_.utcMs();
    // Unsigned subtraction is well-defined even if a damaged settings file
    // contains an extreme signed timestamp. Validate before converting back.
    const quint64 remainingUnsigned = static_cast<quint64>(utcDeadline) - static_cast<quint64>(now);
    // Only a host-validated, previously confirmed deadline may reach here.
    // Reject stale/corrupt settings rather than ever powering off at startup.
    if (mode_ != QStringLiteral("open") || due_ || utcDeadline <= now || remainingUnsigned < 1000 || remainingUnsigned > 10800000
        || originalTotalSeconds < 60 || originalTotalSeconds > 10800
        || remainingUnsigned > static_cast<quint64>(originalTotalSeconds) * 1000) {
        throw std::invalid_argument(QStringLiteral("Сохранённый таймер истёк или повреждён. Запустите отсчёт заново.").toUtf8().constData());
    }
    due_ = clock_.monotonicMs() + static_cast<qint64>(remainingUnsigned);
    totalSeconds_ = originalTotalSeconds;
    confirmationToken_.clear();
    mode_ = previousMode_ = QStringLiteral("closed");
    message_.clear();
}

void ControlModel::confirm()
{
    confirm(confirmationToken_);
}

void ControlModel::confirm(const QString& token)
{
    if (mode_ != QStringLiteral("pending") || token.isEmpty() || token != confirmationToken_)
        throw modelError(QStringLiteral("Подтвердите выключение кнопкой «Точно закрыть?».") );
    if (clock_.monotonicMs() >= confirmationExpires_) {
        dismiss();
        throw modelError(QStringLiteral("Подтверждение истекло. Нажмите «Выключить» ещё раз."));
    }
    due_ = clock_.monotonicMs() + static_cast<qint64>(confirmationMinutes_) * 60000;
    totalSeconds_ = confirmationMinutes_ * 60;
    confirmationToken_.clear();
    mode_ = previousMode_ = QStringLiteral("closed");
    message_.clear();
}

void ControlModel::dismiss()
{
    if (mode_ != QStringLiteral("pending")) return;
    confirmationToken_.clear();
    mode_ = previousMode_ = due_ ? QStringLiteral("closed") : QStringLiteral("open");
}

void ControlModel::cancel()
{
    // Once handed to Windows, only Windows can cancel the system shutdown.
    if (mode_ == QStringLiteral("shuttingDown")) return;
    due_.reset();
    totalSeconds_ = 0;
    confirmationToken_.clear();
    mode_ = previousMode_ = QStringLiteral("open");
    message_.clear();
}

void ControlModel::cancelForSleep()
{
    const bool wasActive = due_.has_value() || mode_ == QStringLiteral("pending");
    cancel();
    if (wasActive)
        message_ = QStringLiteral("Таймер отменён после сна или гибернации. При необходимости запустите его заново.");
}

void ControlModel::tick()
{
    if (mode_ == QStringLiteral("pending") && clock_.monotonicMs() >= confirmationExpires_) dismiss();
    if (!due_ || clock_.monotonicMs() < *due_) return;

    // Consume the deadline before the side effect. Neither a failure nor a
    // repeated GUI tick can cause a second request.
    due_.reset();
    totalSeconds_ = 0;
    confirmationToken_.clear();
    mode_ = previousMode_ = QStringLiteral("shuttingDown");
    try {
        if (demo_) {
            // Guard here, in addition to the host's harmless demo callback.
            mode_ = previousMode_ = QStringLiteral("open");
            message_ = QStringLiteral("Демонстрация завершена. Компьютер продолжает работать.");
        } else {
            shutdown_();
        }
    } catch (const std::exception& error) {
        mode_ = previousMode_ = QStringLiteral("open");
        message_ = QStringLiteral("Windows не приняла выключение: ") + QString::fromUtf8(error.what());
    } catch (...) {
        mode_ = previousMode_ = QStringLiteral("open");
        message_ = QStringLiteral("Windows не приняла выключение. Попробуйте запустить таймер заново.");
    }
}

void ControlModel::shutdownWasCancelled()
{
    if (mode_ != QStringLiteral("shuttingDown")) return;
    mode_ = previousMode_ = QStringLiteral("open");
    message_ = QStringLiteral("Выключение было отменено в Windows. Компьютер остаётся включён.");
}

} // namespace Rework
