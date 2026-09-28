# Этап 3 — UI Kit и базовый дизайн Figma

Выполнен только этап 3 по `docs/tz/TZ_EasyPark.md`. Этап 4 не начат.
Бизнес-логика, авторизация и полноценные экраны не подключены. Все прежние
маршруты остаются заглушками; каталог запускается отдельной точкой входа.

## Созданные файлы и назначение

Все пути ниже относительно `D:\EasyPark`.

| Файл | Назначение |
| --- | --- |
| `mobile/lib/core/theme/app_tokens.dart` | Цвета, типографика, отступы, скругления и градиент |
| `mobile/lib/core/widgets/app_button.dart` | Шесть вариантов кнопок; иконка, disabled, loading, fullWidth |
| `mobile/lib/core/widgets/app_text_field.dart` | Поле формы: label, controller, validator, focus, autofill, ошибка, пароль |
| `mobile/lib/core/widgets/app_card.dart` | Карточка с заголовком, описанием, содержимым и footer |
| `mobile/lib/core/widgets/app_top_bar.dart` | Верхняя панель, название, callback «Назад», actions |
| `mobile/lib/core/widgets/app_loading_indicator.dart` | Индикатор с необязательной подписью и семантикой загрузки |
| `mobile/lib/core/widgets/app_error_view.dart` | Безопасное сообщение об ошибке и необязательный повтор |
| `mobile/lib/core/widgets/app_bottom_navigation.dart` | Контролируемая навигация Карта / Бронирования / Профиль |
| `mobile/lib/core/widgets/ui_kit.dart` | Единая точка импорта |
| `mobile/lib/ui_kit_preview.dart` | Интерактивный каталог для разработки; локальные состояния, без API |
| `mobile/test/ui_kit_test.dart` | Восемь тестов поведения, доступности и адаптивности |
| `mobile/tool/render_ui_kit_test.dart` | Отрисовка каталога Flutter в PNG с реальными шрифтами |
| `docs/stage-3.md` | Этот отчёт |

Изменённые файлы:

- `mobile/lib/core/theme/app_theme.dart` — тема использует токены и оформление полей и AppBar.
- `mobile/pubspec.yaml` — Flutter-библиотека `lucide_icons_flutter`.
- `mobile/pubspec.lock` — закреплена версия Lucide 3.1.20.
- `mobile/README.md` — запуск UI-kit и визуальных проверок.
- `README.md` — актуальный статус проекта и ссылка на каталог.

Сгенерированные результаты (не исходный код):

- `.artifacts/stage-3-390-top.png`
- `.artifacts/stage-3-390-fields.png`
- `.artifacts/stage-3-390-feedback.png`
- `.artifacts/stage-3-320-top.png`
- `.artifacts/stage-3-320-fields.png`
- `.artifacts/stage-3-320-feedback.png`
- `mobile/build/app/outputs/flutter-apk/app-debug.apk` — обновлённая обычная debug-сборка.

Flutter также обновляет производные файлы в `.dart_tool/`, `build/` и Gradle-кешах.
Backend, CV, исходные материалы и контрольная сумма baseline не изменены.

## Перенос дизайна

Основание: `src/styles/globals.css`, `default_theme.css`, компоненты `ui/button.tsx`,
`input.tsx`, `card.tsx`, `tabs.tsx`, а также `LoginScreen.tsx`, `RegisterScreen.tsx`,
`DriverApp.tsx`, `ParkingMap.tsx` локального экспорта. Весь экспорт был изучен
на этапе 0; на этом этапе повторно сверены относящиеся к UI-kit компоненты.

- Основное действие — blue-600 `#155DFC`, нажатие blue-700 `#1447E6`, заголовки blue-900 `#1C398E`.
- Сохранена также нейтральная кнопка `#030213` базового UI-kit.
- Белые карточки, фон `#F9FAFB`, поля `#F3F3F5`, ошибка `#D4183D`, граница чёрная 10%.
- Цвета парковочных статусов взяты из явных SVG fills: `#10B981`, `#EF4444`, `#EAB308`.
- Скругления 6 / 8 / 10 / 14 px. Отступы 4 / 8 / 12 / 16 / 24 / 32 px; карточка 24 px, экран 16 px.
- Заголовки 24 / 20 / 18, основной текст 16, подписи и кнопки 14 px; веса 400/500.
- Иконки Lucide доступны через нативный Flutter font package. React/TSX и web-зависимости не переносились.

Классы цветов разрешены по [исходной палитре Tailwind 4.1.12](https://github.com/tailwindlabs/tailwindcss/blob/v4.1.12/packages/tailwindcss/theme.css).
Flutter-реализация иконок: [lucide_icons_flutter](https://pub.dev/packages/lucide_icons_flutter).
Это справочные источники; приложение не зависит от Tailwind.

Осознанные адаптации под мобильный интерфейс:

- Кнопка имеет визуальную минимальную высоту 36 px и область касания не менее 48 px.
  Поля имеют высоту не менее 48 px; фиксированная высота не обрезает увеличенный текст.
- Используется системная типографика Flutter (Roboto на Android); экспорт не содержит отдельного файла шрифта.
- Верхние tabs водителя из прототипа преобразованы в нижнюю навигацию по ТЗ.
  При ширине менее 450 px и крупном тексте пункты становятся вертикальными для читаемости.
- Название EasyPark взято из ТЗ; брендовый PNG «Лайт Парк» не добавлен в UI-kit.
- Focus-обводка адаптирована средствами Flutter. Тёмная тема не входит в текущий этап.

## Использование

Из `D:\EasyPark\mobile`:

```powershell
flutter run -t lib/ui_kit_preview.dart
```

`AppButton` блокирует callback при loading/disabled. `AppTextField` интегрируется
с обычным `Form`; controller и FocusNode принадлежат вызывающему коду.
`AppErrorView` получает пользовательский текст, например `ApiException.message`,
а не сырое исключение. `AppBottomNavigation` получает selectedIndex и onSelected,
но не управляет router. Для полной страницы loading/error вызывающий экран
задаёт прокрутку и расположение — компоненты не навязывают Scaffold.

## Проверки и исправления

- `dart format --output=none --set-exit-if-changed lib test tool`.
- `flutter analyze` — без замечаний.
- `flutter test` — 29 тестов, включая 21 прежний и 8 новых.
- `flutter test tool/render_ui_kit_test.dart --dart-define=FLUTTER_SDK=C:/Users/User/flutter/flutter --timeout=45s` — отрисовка шести PNG.
- `flutter build apk --debug --no-pub` — Android APK собирается.
- SHA-256: все 75 исходных файлов совпадают с baseline, добавлений в защищённых папках нет.

Проверены нажатия и блокировка кнопок, валидация/submit формы, сокрытие пароля,
семантика загрузки и выбранного пункта, callbacks назад/повтор, прокрутка каталога
при ширинах 320 / 430 / 768 px и масштабе текста 200%.

Исправлены найденные переполнение подписи палитры, разделённая семантика выбранной
вкладки и неудобные переносы нижней навигации при крупном тексте. В утилите
отрисовки исправлены зависания файлового I/O в fake-async и наследование шрифтов
кнопками и AppBar. Замечания форматирования/анализатора устранены.

PNG просмотрены вручную. Это проверка Flutter-рендера, не запуск на физическом
телефоне и не подтверждение попиксельного совпадения всех будущих экранов.
В этом этапе эмулятор повторно не запускался; запуск обычного приложения
на Android был проверен на этапе 0. iOS-сборка требует macOS/Xcode.
