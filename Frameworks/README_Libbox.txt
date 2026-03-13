Чтобы VLESS работал через sing-box, сюда нужно положить Libbox.xcframework.

1. Скачай Libbox.xcframework из одного из источников:
   - https://github.com/khayyamov/xray-singbox-xframework-ios/releases
     (в Releases есть готовый архив с Libbox.xcframework для iOS)
   - https://github.com/SagerNet/sing-box-for-apple (официальный клиент, можно взять xcframework из их сборки)
   - https://github.com/ebrahimtahernejad/sing-box-lib/releases

2. Распакуй архив и помести папку "Libbox.xcframework" в эту папку (Frameworks/),
   чтобы итоговый путь был: testvpn/Frameworks/Libbox.xcframework

3. Открой проект в Xcode и собери (Cmd+B). Таргет VPNExtension линкуется с Libbox.

Без этого шага сборка падает с ошибкой:
   "There is no XCFramework found at '.../Frameworks/Libbox.xcframework'"
После добавления xcframework проект соберётся и VLESS будет работать через sing-box.
