#include "../src/ControlModel.h"

#include <QCoreApplication>
#include <functional>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

using Rework::ControlModel;

namespace {
struct FakeClock final : Rework::Clock {
    qint64 monotonic = 0;
    qint64 utc = 1793275200000;
    qint64 monotonicMs() const override { return monotonic; }
    qint64 utcMs() const override { return utc; }
    void advance(qint64 ms) { monotonic += ms; utc += ms; }
};

void require(bool condition, const char* message)
{
    if (!condition) throw std::runtime_error(message);
}

template<typename T> void equal(const T& expected, const T& actual, const char* message)
{
    require(expected == actual, message);
}

void rejected(const std::function<void()>& action)
{
    try { action(); }
    catch (const std::runtime_error&) { return; }
    throw std::runtime_error("Invalid confirmation was accepted");
}

struct Fixture {
    FakeClock clock;
    int calls = 0;
    bool fail = false;
    ControlModel model;
    explicit Fixture(bool demo = false)
        : model(clock, [this] {
            ++calls;
            if (fail) throw std::runtime_error("Simulated permission failure");
        }, demo) {}
    void start(int minutes) {
        model.prepare(minutes);
        require(!model.confirmationToken().isEmpty(), "First click issues confirmation");
        model.confirm();
        equal(QStringLiteral("closed"), model.mode(), "Second click activates countdown");
    }
};
}

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    int passed = 0;
    int failures = 0;
    const auto test = [&](const char* name, const std::function<void()>& body) {
        try { body(); ++passed; std::cout << "PASS " << name << '\n'; }
        catch (const std::exception& error) { ++failures; std::cerr << "FAIL " << name << ": " << error.what() << '\n'; }
    };

    test("startup is open with default duration and no timer", [] {
        Fixture f;
        equal(QStringLiteral("open"), f.model.mode(), "Startup mode");
        equal(10, f.model.minutes(), "Default minutes");
        equal(qint64(0), f.model.deadlineMs(), "No startup deadline");
        f.clock.advance(86400000); f.model.tick();
        equal(0, f.calls, "Idle never shuts down");
    });
    test("first click cannot schedule or request shutdown", [] {
        Fixture f;
        rejected([&] { f.model.confirm(); });
        f.model.prepare(10);
        equal(QStringLiteral("pending"), f.model.mode(), "First click only asks");
        equal(qint64(0), f.model.deadlineMs(), "First click has no countdown");
        f.clock.advance(700000); f.model.tick();
        equal(0, f.calls, "Unconfirmed timer never powers off");
    });
    test("wrong and replayed tokens cannot confirm or restart", [] {
        Fixture f; f.model.prepare(10);
        const auto token = f.model.confirmationToken();
        rejected([&] { f.model.confirm(QStringLiteral("wrong")); });
        equal(qint64(0), f.model.deadlineMs(), "Wrong token cannot schedule");
        f.model.confirm(token);
        const auto due = f.model.deadlineMs();
        f.clock.advance(2000);
        rejected([&] { f.model.confirm(token); });
        equal(due, f.model.deadlineMs(), "Replay cannot restart");
    });
    test("confirmation expires at exactly 30 seconds", [] {
        Fixture f; f.model.prepare(1);
        const auto token = f.model.confirmationToken();
        f.clock.advance(30000);
        rejected([&] { f.model.confirm(token); });
        equal(QStringLiteral("open"), f.model.mode(), "Expired question is dismissed");
        f.clock.advance(600000); f.model.tick();
        equal(0, f.calls, "Expired confirmation cannot power off");
    });
    test("full countdown starts at second click with ceiling seconds", [] {
        Fixture f; f.model.prepare(10);
        f.clock.advance(8000); f.model.confirm();
        equal(f.clock.utc + 600000, f.model.deadlineMs(), "Deadline begins at confirmation");
        equal(600, f.model.remainingSeconds(), "Full initial duration");
        f.clock.advance(1100); f.model.tick();
        equal(599, f.model.remainingSeconds(), "Ceiling seconds");
        equal(0, f.calls, "No early shutdown");
    });
    test("cancel permanently clears confirmed countdown", [] {
        Fixture f; f.start(1);
        f.clock.advance(59999); f.model.cancel();
        f.clock.advance(3600000); f.model.tick(); f.model.tick();
        equal(QStringLiteral("open"), f.model.mode(), "Cancel returns open");
        equal(qint64(0), f.model.deadlineMs(), "Cancel clears deadline");
        equal(0, f.calls, "Cancel prevents shutdown");
    });
    test("duration preference and first restart click preserve existing timer", [] {
        Fixture f; f.start(10);
        const auto due = f.model.deadlineMs();
        f.model.setDuration(2);
        equal(2, f.model.minutes(), "Preference updates");
        equal(due, f.model.deadlineMs(), "Preference leaves old deadline");
        equal(600, f.model.totalSeconds(), "Progress retains original duration");
        f.model.prepare(2);
        equal(QStringLiteral("closed"), f.model.previousMode(), "Pending remembers active timer");
        equal(due, f.model.deadlineMs(), "First restart click leaves deadline");
        f.model.dismiss();
        equal(due, f.model.deadlineMs(), "Dismiss leaves deadline");
        f.clock.advance(20000); f.model.prepare(2); f.model.confirm();
        equal(f.clock.utc + 120000, f.model.deadlineMs(), "Confirmed restart uses new duration");
    });
    test("pending restart cannot suppress original timer expiry", [] {
        Fixture f; f.start(1);
        f.clock.advance(55000); f.model.prepare(10);
        f.clock.advance(5000); f.model.tick();
        equal(1, f.calls, "Original confirmed timer remains effective");
    });
    test("expiry requests shutdown exactly once", [] {
        Fixture f; f.start(1);
        f.clock.advance(59999); f.model.tick();
        equal(0, f.calls, "Never before monotonic deadline");
        f.clock.advance(1); f.model.tick(); f.model.tick();
        f.clock.advance(3600000); f.model.tick();
        equal(1, f.calls, "One request only");
        equal(QStringLiteral("shuttingDown"), f.model.mode(), "Windows owns shutdown");
    });
    test("shutdown failure is visible with no automatic retry", [] {
        Fixture f; f.fail = true; f.start(1);
        f.clock.advance(60000); f.model.tick(); f.model.tick();
        equal(1, f.calls, "Failure not retried");
        equal(QStringLiteral("open"), f.model.mode(), "Failure returns open");
        require(!f.model.message().isEmpty(), "Failure must be visible");
        equal(qint64(0), f.model.deadlineMs(), "Failure clears timer");
    });
    test("sleep or resume cancels timer and invalidates pending confirmation", [] {
        Fixture f; f.start(1); f.model.prepare(2);
        const auto token = f.model.confirmationToken();
        f.clock.advance(300000); f.model.cancelForSleep();
        rejected([&] { f.model.confirm(token); }); f.model.tick();
        equal(QStringLiteral("open"), f.model.mode(), "Sleep resets mode");
        equal(0, f.calls, "No shutdown after sleep past deadline");
        require(!f.model.message().isEmpty(), "Cancellation is explained");
    });
    test("dismiss invalidates token without scheduling", [] {
        Fixture f; f.model.prepare(1);
        const auto token = f.model.confirmationToken();
        f.model.dismiss(); rejected([&] { f.model.confirm(token); });
        equal(qint64(0), f.model.deadlineMs(), "Dismiss has no countdown");
    });
    test("repeated prepare rotates token and invalidates old question", [] {
        Fixture f; f.model.prepare(1);
        const auto old = f.model.confirmationToken();
        f.model.prepare(2);
        const auto current = f.model.confirmationToken();
        require(old != current, "Tokens rotate");
        rejected([&] { f.model.confirm(old); });
        f.model.confirm(current);
        equal(120, f.model.remainingSeconds(), "Current question confirms current duration");
    });
    test("invalid durations never create a confirmable timer", [] {
        for (int value : {std::numeric_limits<int>::min(), -1, 0, 181, std::numeric_limits<int>::max()}) {
            Fixture f;
            bool invalid = false;
            try { f.model.prepare(value); } catch (const std::invalid_argument&) { invalid = true; }
            require(invalid, "Invalid duration rejected");
            require(f.model.confirmationToken().isEmpty(), "Invalid duration cannot create token");
            equal(qint64(0), f.model.deadlineMs(), "Invalid duration cannot schedule");
        }
        Fixture min; min.start(1); equal(60, min.model.remainingSeconds(), "Minimum accepted");
        Fixture max; max.start(180); equal(10800, max.model.remainingSeconds(), "Maximum accepted");
    });
    test("Windows wall-clock jumps cannot shorten or extend countdown", [] {
        Fixture f; f.start(10);
        f.clock.utc += 86400000; f.model.tick();
        equal(600, f.model.remainingSeconds(), "Forward wall-clock jump does not elapse timer");
        equal(0, f.calls, "Forward jump cannot trigger shutdown");
        equal(f.clock.utc + 600000, f.model.deadlineMs(), "Displayed deadline follows new wall time");
        f.clock.utc -= 172800000; f.clock.advance(30000); f.model.tick();
        equal(570, f.model.remainingSeconds(), "Backward jump does not affect elapsed time");
    });
    test("wall-clock changes cannot revive expired confirmation", [] {
        Fixture f; f.model.prepare(1);
        const auto token = f.model.confirmationToken();
        f.clock.advance(31000); f.clock.utc -= 86400000;
        rejected([&] { f.model.confirm(token); });
        equal(qint64(0), f.model.deadlineMs(), "Expired question remains expired");
    });
    test("preference changes during confirmation require a fresh first click", [] {
        Fixture f; f.model.prepare(10);
        const auto token = f.model.confirmationToken();
        f.model.setDuration(1);
        equal(QStringLiteral("open"), f.model.mode(), "Preference dismisses obsolete question");
        rejected([&] { f.model.confirm(token); });
        f.model.prepare(2); f.model.confirm();
        equal(120, f.model.remainingSeconds(), "Only newly confirmed duration runs");
    });
    test("Windows-aborted shutdown returns to usable model without retry", [] {
        Fixture f; f.start(1); f.clock.advance(60000); f.model.tick();
        f.model.shutdownWasCancelled(); f.model.tick();
        equal(QStringLiteral("open"), f.model.mode(), "Windows cancellation restores open");
        equal(1, f.calls, "No automatic retry");
        f.start(1); f.clock.advance(60000); f.model.tick();
        equal(2, f.calls, "Fresh confirmed timer works");
    });
    test("demo completion cannot invoke shutdown even with an unsafe callback", [] {
        Fixture f(true); f.start(1); f.clock.advance(60000);
        f.model.tick(); f.model.tick();
        equal(0, f.calls, "Demo guards the callback inside model");
        equal(QStringLiteral("open"), f.model.mode(), "Demo completion restores open");
        require(!f.model.message().isEmpty(), "Demo completion is visible");
    });
    test("progress uses monotonic original duration and is bounded", [] {
        Fixture f; f.start(10);
        equal(1.0, f.model.progress(), "Initial progress");
        f.clock.advance(300000); f.model.setDuration(1);
        equal(0.5, f.model.progress(), "Preference cannot distort active progress");
        f.clock.advance(300001);
        equal(0.0, f.model.progress(), "Overdue progress cannot go negative");
        f.model.cancel(); equal(0.0, f.model.progress(), "Cancelled progress clears");
    });
    test("restored future deadline preserves remainder without a startup shutdown", [] {
        Fixture f;
        f.model.restoreCountdown(f.clock.utc + 300000, 600);
        equal(QStringLiteral("closed"), f.model.mode(), "Restored mode");
        equal(300, f.model.remainingSeconds(), "Restore does not restart full duration");
        equal(600, f.model.totalSeconds(), "Restored original duration");
        equal(0.5, f.model.progress(), "Restored progress");
        f.model.tick(); equal(0, f.calls, "Startup restoration does not power off");
        f.clock.utc += 86400000; f.model.tick();
        equal(300, f.model.remainingSeconds(), "Restored deadline uses monotonic time thereafter");
        f.clock.advance(300000); f.model.tick(); f.model.tick();
        equal(1, f.calls, "Restored confirmed timer expires once");
    });
    test("expired or corrupt persisted deadlines cannot request startup shutdown", [] {
        for (const qint64 remaining : {-86400000LL, -1LL, 0LL, 999LL, 10800001LL}) {
            Fixture f;
            bool invalid = false;
            try { f.model.restoreCountdown(f.clock.utc + remaining, 10800); }
            catch (const std::invalid_argument&) { invalid = true; }
            require(invalid, "Unsafe persisted deadline is rejected");
            f.model.tick(); equal(0, f.calls, "Rejected restore cannot power off");
            equal(QStringLiteral("open"), f.model.mode(), "Rejected restore stays open");
        }
        for (const int original : {0, 59, 10801}) {
            Fixture f;
            bool invalid = false;
            try { f.model.restoreCountdown(f.clock.utc + 30000, original); }
            catch (const std::invalid_argument&) { invalid = true; }
            require(invalid, "Invalid original duration rejected");
        }
        for (const qint64 deadline : {std::numeric_limits<qint64>::min(), std::numeric_limits<qint64>::max()}) {
            Fixture f;
            bool invalid = false;
            try { f.model.restoreCountdown(deadline, 600); }
            catch (const std::invalid_argument&) { invalid = true; }
            require(invalid, "Extreme corrupt timestamps rejected without signed overflow");
            f.model.tick(); equal(0, f.calls, "Corrupt timestamp cannot power off");
        }
        Fixture f;
        bool invalid = false;
        try { f.model.restoreCountdown(f.clock.utc + 120000, 60); }
        catch (const std::invalid_argument&) { invalid = true; }
        require(invalid, "Remaining duration cannot exceed original duration");
    });

    std::cout << passed << " model tests passed; " << failures << " failed. No Windows shutdown API was called.\n";
    return failures ? 1 : 0;
}
