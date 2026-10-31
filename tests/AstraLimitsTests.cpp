#include "AstraLimits.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QTextStream>
#include <QTimer>
#include <stdexcept>
int main(int argc, char** argv) {
    QCoreApplication app(argc,argv);
    if (app.arguments().contains("--live")) {
        AstraLimits limits;
        QObject::connect(&limits,&AstraLimits::changed,&app,[&] {
            if (limits.busy()) return;
            QTextStream(stdout) << "Live rows: " << limits.rows().size() << "; stale: " << limits.stale() << "\n";
            app.exit(limits.rows().isEmpty() || limits.stale() ? 1 : 0);
        });
        QTimer::singleShot(30000,&app,[&] { app.exit(2); });
        return app.exec();
    }
    auto parse=[](const char* json) { return AstraLimits::parseRows(QJsonDocument::fromJson(json).object()); };
    auto check=[](bool condition) { if (!condition) throw std::runtime_error("Astra parser failed"); };
    check(parse("{}").isEmpty());
    auto rows=parse(R"({"rateLimits":{"primary":{"usedPercent":27,"windowDurationMins":300,"resetsAt":1800000000},"secondary":{"usedPercent":100,"windowDurationMins":10080}}})");
    check(rows.size()==2 && rows[0].toMap()["remaining"].toDouble()==73 && rows[1].toMap()["remaining"].toDouble()==0);
    check(rows[0].toMap()["resetMs"].toDouble()==1800000000000.0);
    check(parse(R"({"rateLimits":{"primary":{"usedPercent":null}}})")[0].toMap()["remaining"].toDouble()==-1);
    check(parse(R"({"rateLimits":{"primary":{"usedPercent":101}}})")[0].toMap()["remaining"].toDouble()==-1);
    rows=parse(R"({"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":5}},"other":{"secondary":{"usedPercent":10}}},"rateLimits":{"primary":{"usedPercent":50}}})");
    check(rows.size()==2 && rows[0].toMap()["remaining"].toDouble()==95);
    QTextStream(stdout) << "Astra parser checks passed\n";
    return 0;
}
