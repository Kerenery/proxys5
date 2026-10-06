# proxys5

SOCKS5-прокси на базе [Dante](https://www.inet.no/dante/) в Docker-контейнере, с автодеплоем на VPS через GitHub Actions.

## Как это устроено

| Файл | Назначение |
|---|---|
| [Dockerfile](Dockerfile) | Собирает образ: Debian 12-slim + `dante-server`, кладёт внутрь `danted.conf.template` и `entrypoint.sh` |
| [entrypoint.sh](entrypoint.sh) | Стартовый скрипт контейнера: настраивает PAM, определяет внешний IP, рендерит `danted.conf` из шаблона, создаёт пользователя прокси и паролит его, запускает `danted` |
| [danted.conf.template](danted.conf.template) | Шаблон конфига Dante (`envsubst` подставляет `${INTERFACE}`) |
| [docker-compose.yaml](docker-compose.yaml) | Запуск готового образа из GHCR на сервере, `network_mode: host`, читает `.env` |
| [startup.sh](startup.sh) | Одноразовый скрипт первичной настройки VPS: ставит Docker, ufw, открывает порты 22 и 1080 |
| [.github/workflows/deploy.yaml](.github/workflows/deploy.yaml) | CI/CD: собирает образ → пушит в GHCR → по SSH раскладывает `docker-compose.yaml`/`.env` на сервере → поднимает контейнер |

Образ публикуется в GitHub Container Registry как `ghcr.io/<владелец_репозитория>/socks5-proxy:latest` (имя владельца подставляется автоматически из `github.repository_owner`, в нижнем регистре).

## Что поменять при клонировании / форке

1. **`docker-compose.yaml`** — `image:` захардкожен как `ghcr.io/kerenery/socks5-proxy:latest`. Если репозиторий форкается или переносится под другого владельца/организацию, замените `kerenery` на новый `github.repository_owner` (в нижнем регистре), иначе деплой будет тянуть чужой образ.
2. **GitHub Secrets репозитория** (Settings → Secrets and variables → Actions) — см. таблицу ниже, без них workflow упадёт на шагах SSH/логина в GHCR.
3. **`.env` на сервере** — файл `/opt/socks5/.env` генерируется автоматически пайплайном из секретов `SOCKS_USER`/`SOCKS_PASSWORD`, вручную его создавать не нужно (но см. раздел «Ручной деплой» ниже, если CI не используется). Локальный `.env.example` — просто образец для ручного запуска.
4. **Порт и firewall** — прокси слушает `1080/tcp`. `startup.sh` открывает в `ufw` только `22` (SSH) и `1080`. Если нужен другой порт — поменять и в `startup.sh` (ufw), и в `danted.conf.template` (`internal: 0.0.0.0 port = 1080`), и в `EXPOSE` в Dockerfile.

## Откуда брать секреты

Секреты задаются в **Settings → Secrets and variables → Actions** репозитория на GitHub.

| Secret | Что это | Откуда взять | Пример значения |
|---|---|---|---|
| `VPS_HOST` | IP или домен сервера | Из панели вашего хостинга/VPS-провайдера | `195.201.34.12` |
| `VPS_USER` | Пользователь для SSH-подключения | Обычно `root` либо созданный вами deploy-пользователь с sudo | `root` |
| `VPS_SSH_KEY` | Приватный SSH-ключ (в чистом виде, без пароля) | Сгенерировать `ssh-keygen -t ed25519 -C "deploy"` локально, публичную часть (`.pub`) добавить в `~/.ssh/authorized_keys` на сервере, приватную — вставить в этот секрет | `-----BEGIN OPENSSH PRIVATE KEY-----`<br>`b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAAB...`<br>`-----END OPENSSH PRIVATE KEY-----` |
| `GHCR_TOKEN` | Personal Access Token с правом `write:packages` (и `read:packages`) | GitHub → Settings → Developer settings → Personal access tokens (classic или fine-grained). Нужен отдельно от встроенного `GITHUB_TOKEN`, т.к. используется для `docker login` **на самом VPS** во время деплоя, а не в самом раннере | `ghp_16C7e42F292c6912E7710c838347Ae178B4a` |
| `SOCKS_USER` | Логин для авторизации в SOCKS5 | Придумываете сами | `proxyuser` |
| `SOCKS_PASSWORD` | Пароль для авторизации в SOCKS5 | Придумываете сами (используйте генератор паролей) | `k9F2!vQ7z-XmP1w` |

`GITHUB_TOKEN` в шаге сборки/пуша образа в GHCR ничего настраивать не нужно — он выдаётся GitHub Actions автоматически на время работы workflow.

## Как происходит деплой (CI/CD)

При пуше в `main`:

1. **build** — собирает Docker-образ и пушит его в `ghcr.io/<owner>/socks5-proxy:latest`, авторизуясь встроенным `GITHUB_TOKEN`.
2. **deploy**:
   - проверяет SSH-доступ к `VPS_HOST`;
   - копирует `startup.sh` и `docker-compose.yaml` на сервер в `/tmp/socks5`;
   - если на сервере ещё нет `/opt/socks5/.initialized` — прогоняет `startup.sh` (ставит Docker/ufw, открывает порты) и создаёт маркер;
   - копирует `docker-compose.yaml` в `/opt/socks5`;
   - генерирует `/opt/socks5/.env` из секретов `SOCKS_USER`/`SOCKS_PASSWORD`;
   - логинится в GHCR на сервере через `GHCR_TOKEN`;
   - `docker compose pull && docker compose up -d --force-recreate`.

Повторные пуши в `main` пропускают `startup.sh` (сервер уже "initialized") и просто обновляют образ/конфиг.

## Первый запуск нового сервера

Ничего руками делать не нужно — просто:
1. Поднять чистый VPS (Debian/Ubuntu) и добавить его данные и SSH-ключ в секреты.
2. Запушить в `main` (или сделать `workflow_dispatch`, если добавить триггер) — пайплайн сам выполнит `startup.sh`, поставит Docker, настроит firewall и поднимет контейнер.

## Ручной запуск (без CI, для локальной проверки или сервера без GitHub Actions)

```bash
git clone git@github.com:<owner>/proxys5.git
cd proxys5
cp .env.example .env
# отредактировать .env: указать свои SOCKS_USER / SOCKS_PASSWORD
docker build -t socks5-proxy:local .
docker run -d --name socks5 --network host --env-file .env socks5-proxy:local
```

Либо через compose (сначала поправить `image:` в `docker-compose.yaml` на локально собранный тег, либо на свой `ghcr.io/<owner>/socks5-proxy:latest`):

```bash
docker compose up -d --build
```

## Проверка работоспособности

```bash
curl -x socks5://<SOCKS_USER>:<SOCKS_PASSWORD>@<VPS_HOST>:1080 https://ifconfig.me
```

Должен вернуться внешний IP сервера.

## Важные нюансы безопасности

- `danted.conf.template` разрешает подключения `from: 0.0.0.0/0` — прокси доступен всем в интернете, кто знает логин/пароль. Авторизация обязательна (`socksmethod: username`), но трафик между клиентом и прокси **не шифруется** (обычный SOCKS5, не SOCKS5-over-TLS) — учитывайте это при выборе, что через него пускать.
- `debug: 1` в конфиге включает подробный лог соединений (via `logoutput: stderr`, т.е. в `docker logs`) — при необходимости снизить/выключить для продакшена.
- `.env` с реальными паролями не должен попадать в git — сейчас `.gitignore` его не исключает, стоит добавить `.env` туда, если планируете держать локальный `.env` в рабочей копии.
- `network_mode: host` — контейнер использует сетевой стек хоста напрямую, порт `1080` слушается на всех интерфейсах сервера.
- ⚠️ **`startup.sh` делает `ufw --force reset`** ([startup.sh:44](startup.sh:44)) — это стирает **все** существующие правила ufw на сервере, а не только связанные с прокси, и уже потом открывает `22` и `1080`. Если на VPS уже есть другие сервисы с открытыми портами, они «закроются». В пайплайне это частично смягчено маркером `/opt/socks5/.initialized` — `startup.sh` выполняется только при первом деплое на конкретный сервер, — но при разворачивании на уже настроенный сервер, либо при случайном удалении маркера, сброс произойдёт и стрёт текущие правила. Разворачивать имеет смысл только на «чистый» сервер, выделенный под этот прокси, либо перед использованием убрать/переписать блок сброса firewall в `startup.sh`.
