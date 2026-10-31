#pragma once

#include <QString>
#include <QtGlobal>
#include <functional>
#include <optional>

namespace Rework {

struct Clock {
    virtual ~Clock() = default;
    virtual qint64 monotonicMs() const = 0;
    virtual qint64 utcMs() const = 0;
};

using Shutdown = std::function<void()>;

// Pure state model. Only tick() may request shutdown, and only after a
// separately confirmed monotonic deadline. Nothing is scheduled in Windows.
class ControlModel final {
public:
    ControlModel(Clock& clock, Shutdown shutdown, bool demo = false);

    QString mode() const { return mode_; }
    QString previousMode() const { return previousMode_; }
    int minutes() const { return minutes_; }
    int remainingSeconds() const;
    qint64 remainingMilliseconds() const { return remainingMs(); }
    int totalSeconds() const { return totalSeconds_; }
    qint64 deadlineMs() const;
    double progress() const;
    QString confirmationToken() const { return confirmationToken_; }
    QString message() const { return message_; }
    bool demo() const { return demo_; }

    void prepare(int minutes);
    void confirm();
    void confirm(const QString& token);
    void dismiss();
    void cancel();
    void setDuration(int minutes);
    void restoreCountdown(qint64 utcDeadline, int originalTotalSeconds);
    void tick();
    void cancelForSleep();
    void shutdownWasCancelled();
    void setMessage(const QString& message) { message_ = message; }

private:
    static void validateMinutes(int minutes);
    qint64 remainingMs() const;

    Clock& clock_;
    Shutdown shutdown_;
    bool demo_ = false;
    QString mode_ = QStringLiteral("open");
    QString previousMode_ = QStringLiteral("open");
    int minutes_ = 10;
    int totalSeconds_ = 0;
    std::optional<qint64> due_;
    int confirmationMinutes_ = 10;
    qint64 confirmationExpires_ = 0;
    QString confirmationToken_;
    QString message_;
};

} // namespace Rework
