// Copyright (C) 2026 Graham Strickland
//
// This file is part of LoopMac.
//
// LoopMac is free software: you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option) any
// later version.
//
// LoopMac is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with LoopMac. If not, see <https://www.gnu.org/licenses/>.

#include <QCommandLineParser>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);

  QCoreApplication::setApplicationName("LoopMac");
  QCoreApplication::setOrganizationName("Graham Strickland");
  QCoreApplication::setApplicationVersion(QT_VERSION_STR);
  QCommandLineParser parser;
  parser.setApplicationDescription("Audio loopback and replay application");
  parser.addHelpOption();
  parser.addVersionOption();
  parser.addPositionalArgument("url", "The URL(s) to open.");
  parser.process(app);

  QQmlApplicationEngine engine;
  const QUrl url(QStringLiteral("qrc:/Main.qml"));

  if (!parser.positionalArguments().isEmpty()) {
    QUrl source = QUrl::fromUserInput(parser.positionalArguments().at(0),
                                      QDir::currentPath());
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &engine,
                     [source](QObject *object, const QUrl &) {
                       qDebug() << "setting source";
                       object->setProperty("source", source);
                     });
  }

  engine.loadFromModule("LoopMac", "Main");

  return app.exec();
}
