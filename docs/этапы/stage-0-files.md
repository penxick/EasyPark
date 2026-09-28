# Файлы этапа 0

Все перечисленные файлы созданы в ходе этапа 0. Предсуществовавшие ТЗ и
Figma-экспорт не изменены. Файлы шаблона Flutter настроены после генерации:
`lib/main.dart`, `test/widget_test.dart`, `pubspec.yaml`, `README.md`,
Android `AndroidManifest.xml`, iOS `Info.plist`.

## Назначение основных файлов

| Файлы                                                          | Назначение                                                                                       |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `docker-compose.yml`, `.env.example`, `.env`                   | PostgreSQL и два сервиса, порты, healthcheck, постоянный том; `.env` локальный и исключён из Git |
| `.gitignore`, `.editorconfig`                                  | Исключения для кешей/локальных данных, базовые правила форматирования                            |
| `README.md`                                                    | Запуск, зависимости, команды проверки                                                            |
| `backend/src/main.ts`, `app.module.ts`, `health.controller.ts` | Запуск NestJS, корневой модуль, `GET /health`                                                    |
| `backend/package*.json`, `tsconfig.json`, `nest-cli.json`      | Версии зависимостей и сборка TypeScript/NestJS                                                   |
| `backend/eslint.config.mjs`, `.prettier*`                      | Lint и форматирование                                                                            |
| `backend/test/health.test.cjs`                                 | Проверка реального HTTP endpoint и отсутствия бизнес-API                                         |
| `backend/Dockerfile`, `.dockerignore`                          | Сборка и runtime-контейнер NestJS                                                                |
| `cv-service/app/*.py`                                          | FastAPI и `GET /health`                                                                          |
| `cv-service/requirements*.in`, `requirements*.txt`             | Прямые зависимости и закреплённые версии runtime/dev                                             |
| `cv-service/pyproject.toml`, `tests/test_health.py`            | Ruff, pytest и проверки API                                                                      |
| `cv-service/Dockerfile`, `.dockerignore`                       | Контейнер FastAPI                                                                                |
| `mobile/lib/main.dart`, `test/widget_test.dart`                | Минимальный стартовый экран и smoke test                                                         |
| `mobile/pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` | Flutter-зависимости и анализатор                                                                 |
| `mobile/android/**`, `mobile/ios/**`                           | Нативные проекты, manifest/plist, Gradle/Xcode, стандартные ресурсы шаблона                      |
| `mobile/.metadata`, `.gitignore`, `.idea/**`, `*.iml`          | Метаданные Flutter/IDE; локальные IDE-файлы исключены из Git                                     |
| `source-materials.sha256.json`                                 | Контрольные суммы неизменяемых исходников                                                        |
| `docs/stage-0.md`, `docs/stage-0-files.md`                     | Отчёт и реестр файлов                                                                            |

## Пофайловый список

Включает код, ресурсы, конфигурацию и локальные платформенные файлы. Зависимости,
кеши и сборки вынесены в полный машинный реестр ниже.

- `.editorconfig`
- `.env`
- `.env.example`
- `.gitignore`
- `README.md`
- `backend/.dockerignore`
- `backend/.prettierignore`
- `backend/.prettierrc.json`
- `backend/Dockerfile`
- `backend/eslint.config.mjs`
- `backend/nest-cli.json`
- `backend/package-lock.json`
- `backend/package.json`
- `backend/src/app.module.ts`
- `backend/src/health.controller.ts`
- `backend/src/main.ts`
- `backend/test/health.test.cjs`
- `backend/tsconfig.json`
- `cv-service/.dockerignore`
- `cv-service/Dockerfile`
- `cv-service/app/__init__.py`
- `cv-service/app/main.py`
- `cv-service/pyproject.toml`
- `cv-service/requirements-dev.in`
- `cv-service/requirements-dev.txt`
- `cv-service/requirements.in`
- `cv-service/requirements.txt`
- `cv-service/tests/test_health.py`
- `docker-compose.yml`
- `docs/stage-0-files.md`
- `docs/stage-0.md`
- `mobile/.gitignore`
- `mobile/.idea/libraries/Dart_SDK.xml`
- `mobile/.idea/libraries/KotlinJavaRuntime.xml`
- `mobile/.idea/modules.xml`
- `mobile/.idea/runConfigurations/main_dart.xml`
- `mobile/.idea/workspace.xml`
- `mobile/.metadata`
- `mobile/README.md`
- `mobile/analysis_options.yaml`
- `mobile/android/.gitignore`
- `mobile/android/app/build.gradle.kts`
- `mobile/android/app/src/debug/AndroidManifest.xml`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- `mobile/android/app/src/main/kotlin/com/easypark/easypark/MainActivity.kt`
- `mobile/android/app/src/main/res/drawable-v21/launch_background.xml`
- `mobile/android/app/src/main/res/drawable/launch_background.xml`
- `mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/values-night/styles.xml`
- `mobile/android/app/src/main/res/values/styles.xml`
- `mobile/android/app/src/profile/AndroidManifest.xml`
- `mobile/android/build.gradle.kts`
- `mobile/android/easypark_android.iml`
- `mobile/android/gradle.properties`
- `mobile/android/gradle/wrapper/gradle-wrapper.jar`
- `mobile/android/gradle/wrapper/gradle-wrapper.properties`
- `mobile/android/gradlew`
- `mobile/android/gradlew.bat`
- `mobile/android/local.properties`
- `mobile/android/settings.gradle.kts`
- `mobile/easypark.iml`
- `mobile/ios/.gitignore`
- `mobile/ios/Flutter/AppFrameworkInfo.plist`
- `mobile/ios/Flutter/Debug.xcconfig`
- `mobile/ios/Flutter/Generated.xcconfig`
- `mobile/ios/Flutter/Release.xcconfig`
- `mobile/ios/Flutter/flutter_export_environment.sh`
- `mobile/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- `mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`
- `mobile/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `mobile/ios/Runner.xcworkspace/contents.xcworkspacedata`
- `mobile/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `mobile/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`
- `mobile/ios/Runner/AppDelegate.swift`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`
- `mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `mobile/ios/Runner/Base.lproj/Main.storyboard`
- `mobile/ios/Runner/GeneratedPluginRegistrant.h`
- `mobile/ios/Runner/GeneratedPluginRegistrant.m`
- `mobile/ios/Runner/Info.plist`
- `mobile/ios/Runner/Runner-Bridging-Header.h`
- `mobile/ios/RunnerTests/RunnerTests.swift`
- `mobile/lib/main.dart`
- `mobile/pubspec.lock`
- `mobile/pubspec.yaml`
- `mobile/test/widget_test.dart`
- `source-materials.sha256.json`

## Сгенерированные зависимости, кеши и результаты

Полный список **всех файлов внутри корня проекта**, созданных установкой,
генерацией и сборкой (включая `node_modules`, `.venv`, Flutter/Gradle caches),
сохранён в [машинном реестре](../.artifacts/stage-0-all-created-files.txt).
Исходные материалы из него исключены. Внешние кеши SDK и данные Docker
не являются файлами проекта и этим реестром не охватываются.

Основные результаты:

- `mobile/build/app/outputs/flutter-apk/app-debug.apk` — debug APK.
- `.artifacts/stage-0-android.png` — снимок экрана эмулятора.
- `.artifacts/compose-final.log` — журнал финальной сборки и запуска Compose.
- `.artifacts/emulator.log`, `.artifacts/emulator-error.log` — диагностика эмулятора.
- `backend/dist/` — скомпилированный NestJS.
- `backend/node_modules/`, `cv-service/.venv/` — локальные зависимости.
- `mobile/.dart_tool/`, `mobile/build/`, `mobile/android/.gradle/` — кеши и результаты сборки.
