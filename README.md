# Kitapp

Кыргызча электрондук китеп дүкөнүнүн MVP-версиясы: Flutter веб-тиркеме,
NestJS API жана кыргыз тилиндеги веб-админка.

## Локалдык иштетүү

Талаптар: Node.js, Flutter, Docker Desktop.

```bash
npm install
docker compose up -d
cp server/.env.example server/.env
npm --workspace server run db:migrate
npm --workspace server run db:seed
npm run dev:server
```

Экинчи терминалда админканы иштетиңиз:

```bash
npm run dev:admin
```

- Админка: http://127.0.0.1:5173
- API: http://127.0.0.1:3000/api
- MinIO: http://127.0.0.1:9001
- PostgreSQL: `127.0.0.1:55432`
- Админ: `admin@kitapp.kg` / `Kitapp123!`
- Локалдык SMS-код: `111111`

Flutter веб-тиркемесин өзүнчө иштетүү:

```bash
flutter run -d web-server --web-port 8083
```

## MVP чектөөлөрү

- Колдонуучу телефон номери аркылуу гана кирет.
- Интерфейс кыргыз тилинде.
- Офлайн режим жана түзмөктөр аралык синхрондоштуруу жок.
- Админ-панель веб үчүн гана жасалган.
- Сатуу отчёту мезгил боюнча китепти, авторду, санын жана кирешени көрсөтөт.

## Текшерүүлөр

```bash
npm run check
node tool/qa_admin_api.cjs
flutter analyze
flutter test
```
