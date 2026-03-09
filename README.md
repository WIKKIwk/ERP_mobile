# Mobile App

Flutter Android-first app skeleton for the supplier and werka workflow.

## Bu dastur qayerdan ochildi

VS Code ichidagi terminaldan shu papka ichida ochilgan:

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
flutter run -d linux --dart-define=MOBILE_API_BASE_URL=http://127.0.0.1:8081
```

## Eng qulay qayta ochish usuli

Shu papka ichida tayyor script bor:

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
./run_linux_preview.sh
```

Yoki `make` bilan:

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
make run
```

Bu target kerak bo'lsa `mobileapi` backend’ni ham o'zi ko'taradi.

## Muhim

`make run` va `make web` backend healthcheck qiladi, backend ishlamasa o'zi yoqadi.

## Optional web preview

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
flutter run -d chrome --dart-define=MOBILE_API_BASE_URL=http://127.0.0.1:8081
```

Yoki:

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
make web
```

## Android ni uzoqdan test qilish

Laptopning o'zi core bo'ladi. Telefon boshqa davlatda bo'lsa ham ishlatish mumkin.

Public URL ochish:

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
make remote-up
```

URL'ni ko'rish:

```bash
make remote-url
```

O'sha URL bilan debug APK build qilish:

```bash
make android-sdk-setup
make apk-remote
```

Natija:

```bash
build/app/outputs/flutter-apk/app-debug.apk
```

Ish tugagach tunnel va core'ni to'xtatish:

```bash
make remote-stop
```

## Doimiy domen bilan ishlatish

Doimiy hostname:

```bash
https://core.wspace.sbs
```

Core'ni shu hostname bilan ko'tarish:

```bash
cd /home/wikki/local.git/erpnext_stock_telegram/mobile_app
make domain-up
```

Domain URL'ni ko'rish:

```bash
make domain-url
```

APK'ni doimiy URL bilan build qilish:

```bash
make apk-domain
```
