![](https://media.discordapp.net/attachments/447759797400633377/560445767991558175/dialogimguiv5.png)

# English

This script changes the dialog interface from DXUT to ImGui.

Requirements:
* [SAMPFUNCS](https://blast.hk/threads/17/)
* [MoonLoader](https://blast.hk/threads/13305/)
* [MoonImGui](https://blast.hk/threads/19292/)

Installation: from the archive **dialog_imgui_v7.rar** transfer files to the **moonloader** folder.

Download:
* [GitHub Release](https://github.com/imring/dialog-imgui-lua/releases/latest)
* [BlastHack](https://blast.hk/threads/32007/)

## Settings
Activate menu: /disettings

* Enable Dialog ImGui - enable dialog with the new interface (standard included).
* Return the standard dialog when pressing F8 - returns the standard (DXUT) dialog when saving a screenshot.
* Enable Dialog Hider - this feature allows you to enable dialog after it is closed. (this function is not available since version 6.0).
* Enable item retention after closing.
* Enable layout display - includes the display of the keyboard layout near the input line.

## Updates

### Version 1.0
* Release.

### Version 2.0
* Fixed bug with button Shift.
* Added auto-focus Editbox for dialogs 1 and 3 styles.
* Added Dialog Hider.
* Added saver item selection.

### Version 3.0
* Fixed bugs.
* Added settings in the game.

### Version 4.0
* Fixed bug with ESC.
* Fixed bug with the new version of MoonImGui (1.1.3+).
* Fixed bug with clinging dialog elements.
* Fixed bugs with dialogs 5 and 4 styles (an extra column in some cases and navigation).
* Added display of the layout in the dialog.
* Added AlphaBar (transparency) when changing color.
* New title bar. Thanks [DonHomka](https://github.com/DonHomka) for the code.

### Version 5.0
* Added the ability to turn off/on the standard dialog.
* Added the ability to include a standard dialog when pressing F8.
* Fixed bug with dialogs 4 and 5 styles.
* The layout is now on the right side.
* Now you do not need to reload the script/game to change the font.

### Version 6.0
* Fixed bug with width in dialogs 4 and 5 styles.
* Now the script is compatible with other scripts that work with dialogs.
* Added a check for the presence of a font (if there is no font, then it will be font Arial).
* Recalculated height in dialogs.
* Removed Dialog Hider.
* Added indent in ColorEdit.

### Version 7.0
* Fixed problem with .ini.
* Fixed bug with the choice of the element in dialogs 4 and 5 styles.

### Version 8.0
* Fixed bugs in dialogs 4 and 5 styles.
* Fixed not valid characters.
* Fixed size calculation provided.

# Русский

Данный скрипт меняет интерфейс диалога с DXUT на ImGui.

Требования:
* [SAMPFUNCS](https://blast.hk/threads/17/)
* [MoonLoader](https://blast.hk/threads/13305/)
* [MoonImGui](https://blast.hk/threads/19292/)

Установка: с архива **dialog_imgui_v7.rar** перести файлы в папку **moonloader**.

Скачать:
* [GitHub Release](https://github.com/imring/dialog-imgui-lua/releases/latest)
* [BlastHack](https://blast.hk/threads/32007/)

## Настройки
Активация меню: /disettings

* Включить Dialog ImGui - включить непосредственно диалог с новым интерфейсом (по-стандартному включен).
* Возвращать стандарт. диалог при нажатие F8 - возвращает стандартный (DXUT) диалог при сохранении скриншота.
* Включить Dialog Hider - данная функция позволяет включить диалог после его закрытия (данной функции нету начиная с версии 6.0).
* Включить сохранение элементов после закрытия.
* Включить показ раскладки - включает возле ввода строки показ раскладки клавиатуры.

## Обновления

### Версия 1.0
* Релиз.

### Версия 2.0
* Исправлен баг с кнопкой Shift.
* Добавлен авто-фокусирование Editbox в диалогах 1 и 3 стиля.
* Добавлен Dialog Hider.
* Добавлено сохранение выбранных элементов.

### Версия 3.0
* Исправлены баги.
* Добавлены настройки прямо в игре.

### Версия 4.0
* Исправлен баг с ESC.
* Исправлен баг с новой версией MoonImGui (1.1.3+).
* Исправлен баг с прилипанием элементов диалога.
* Исправлены баги в диалогах 4 и 5 стиля (лишний столбец в некоторых случаях и навигация).
* Добавлен показ раскладки.
* Добавлен AlphaBar (прозрачность) при изменении цвета.
* Новый вид заголовка. Спасибо [DonHomka](https://github.com/DonHomka) за код.

### Версия 5.0
* Добавлена возможность включить/выключить стандартный диалог.
* Добавлена возможность возвращать стандартый диалог при нажатии F8.
* Исправлены баги в диалогах 4 и 5 стиля.
* Раскладка теперь на правой стороне.
* Теперь не надо перезагружать скрипт/игру чтобы изменить шрифт.

### Версия 6.0
* Исправлен баг с шириной в диалогах 4 и 5 стиля.
* Теперь скрипт совместим с другими скриптами.
* Добавлена проверка на наличии скрипта (если шрифта не будет, то будет шрифт Arial).
* Пересчитана высота в диалогах.
* Убрал Dialog Hider.
* Добавлен отступ в ColorEdit.

### Версия 7.0
* Исправлена проблема с .ini.
* Исправлен баг с выбором элемента в диалогах 4 и 5 стиля.

### Версия 8.0
* Исправлены баги в диалогах 4 и 5 стиля.
* Исправлены не валидные символы.
* Исправлен подсчет размера диалога.
* Настройки теперь на английском языке.
