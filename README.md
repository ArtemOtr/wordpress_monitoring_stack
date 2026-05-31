# DevOps Курсовая: Мониторинг и Наблюдаемость с Zabbix + GrayLog

Комплексное решение для мониторинга и логирования WordPress приложения с использованием:
- **Zabbix** - метрики и алерты
- **GrayLog** - централизованное логирование
- **Docker** - контейнеризация

## 📋 Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                   Docker Network (zabbix-net)           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │           MONITORING (Zabbix)                    │  │
│  │  ┌─────────┐  ┌──────────────┐  ┌────────────┐  │  │
│  │  │Zabbix   │  │Zabbix Server │  │Zabbix Web  │  │  │
│  │  │Database │  │(port 10051)  │  │UI (8088)   │  │  │
│  │  │MariaDB  │  │              │  │            │  │  │
│  │  └─────────┘  └──────────────┘  └────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │        LOGGING (GrayLog)                         │  │
│  │  ┌──────────┐  ┌────────────┐  ┌────────────┐   │  │
│  │  │MongoDB   │  │Elasticsearch│  │GrayLog UI  │   │  │
│  │  │          │  │(9200)      │  │(9000)      │   │  │
│  │  └──────────┘  └────────────┘  └────────────┘   │  │
│  │                                                  │  │
│  │  ┌──────────────────────────────────────────┐   │  │
│  │  │ Fluent Bit (Log Collector)               │   │  │
│  │  │ Docker Logs → GELF → GrayLog (12201 UDP)│   │  │
│  │  └──────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │        APPLICATIONS + AGENTS                     │  │
│  │  ┌──────────────┐  ┌──────────────────────────┐ │  │
│  │  │nginx-custom  │  │ wordpress + mysql-wp     │ │  │
│  │  │+ Zabbix      │  │ + Zabbix Agent2          │ │  │
│  │  │Agent2        │  │                          │ │  │
│  │  └──────────────┘  └──────────────────────────┘ │  │
│  │  (nginx: 81)       (wordpress: 82, mysql: 3306)  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Быстрый старт

### Требования
- Docker (20.10+)
- Docker Compose (2.0+)
- 8GB RAM минимум
- Linux/macOS (рекомендуется)

### Запуск всего стека

```bash
# 1. Запустить все контейнеры
docker-compose up -d

# 2. Дождаться инициализации (2-3 минуты)
docker-compose logs -f

# 3. Инициализировать GrayLog inputs
bash init-graylog.sh

# 4. Проверить статус
docker-compose ps
```

### Доступ к сервисам

| Сервис | URL | Credentials |
|--------|-----|-------------|
| **Zabbix UI** | http://localhost:8088 | admin / zabbix |
| **GrayLog UI** | http://localhost:9000 | admin / admin |
| **WordPress** | http://localhost:82 | - |
| **Nginx** | http://localhost:81 | - |

## 📊 Использование

### Zabbix

1. Откройте http://localhost:8088
2. Авторизуйтесь (admin/zabbix)
3. Перейдите в **Monitoring > Hosts**
4. Вы должны увидеть 3 хоста с агентами:
   - `nginx-custom`
   - `mysql-wp`
   - `wordpress`

### Если хостов нет
Если хосты не появились, добавьте их вручную через Zabbix UI:

1. Перейдите в **Configuration > Hosts**
2. Нажмите **Create host**
3. Заполните поля:
   - **Host name:** `nginx-custom` / `mysql-wp` / `wordpress`
   - **Visible name:** тот же, что и Host name
   - **Groups:** `Linux servers`
4. В секции **Interfaces** добавьте:
   - **Type:** Agent
   - **DNS name:** `nginx-custom` / `mysql-wp` / `wordpress`
   - **Port:** `10050`
5. В секции **Templates** добавьте шаблоны:
   - `Linux by Zabbix agent` для всех хостов
   - `Nginx by Zabbix agent` для `nginx-custom`
   - `Apache by Zabbix agent` для `wordpress`
6. Нажмите **Add**.

Если после этого хост все еще не появляется, проверьте, что контейнеры запущены и агенты работают.

### GrayLog

1. Откройте http://localhost:9000
2. Авторизуйтесь (admin/admin)
3. Перейдите в **System > Inputs**
4. Вы должны увидеть два input'а:
   - Docker Logs (Fluent Bit) - GELF на 12201 UDP
   - System Syslog - на 5140 UDP

### Если input'ов нет
Если нужные input'ы не появились, создайте их вручную:

1. Перейдите в **System > Inputs**
2. Нажмите **Launch new input**
3. Выберите node `All nodes` или `This node`
4. В списке найдите **GELF UDP** и нажмите **Launch new input**
5. Настройте:
   - **Bind address:** `0.0.0.0`
   - **Port:** `12201`
   - **Receive Buffer Size:** `262144`
6. Нажмите **Save**

7. Снова нажмите **Launch new input**
8. Выберите **Syslog UDP**
9. Настройте:
   - **Bind address:** `0.0.0.0`
   - **Port:** `5140`
   - **Receive Buffer Size:** `262144`
10. Нажмите **Save**

#### Первые запросы

```
# Все логи Docker контейнеров
source:docker*

# Логи WordPress
hostname:wordpress

# Логи Nginx
hostname:nginx-custom

# Ошибки
level:[ERROR, CRITICAL]
```

## 🔍 Отладка

### Проверить логи контейнеров

```bash
# Zabbix
docker-compose logs zabbix-server
docker-compose logs zabbix-web

# GrayLog
docker-compose logs graylog
docker-compose logs mongodb
docker-compose logs elasticsearch

# Логирование
docker-compose logs fluent-bit
```

### Fluent Bit и GrayLog: Docker vs systemd

В этом проекте Fluent Bit запускается как Docker-контейнер, а не как systemd-сервис.

- Файл конфигурации, используемый контейнером, находится здесь:
  - `./fluent-bit/fluent-bit.conf`
- Внутри Docker-сети `docker-compose` имя хоста `graylog` правильно резолвится в контейнере GrayLog.
- Поэтому строка `Host graylog` в `./fluent-bit/fluent-bit.conf` корректна для запуска через `docker-compose`.

Если же вы используете Fluent Bit на хосте Linux вне Docker, то `/etc/fluent-bit/fluent-bit.conf` должен использовать реальный IP или `localhost`:

- `Host 127.0.0.1` — если GrayLog доступен на localhost через проброшенный порт 12201
- `Host <IP-сервера>` — если GrayLog запускается на другом хосте

И тогда нужно перезапустить сервис так:

```bash
sudo systemctl restart fluent-bit
sudo journalctl -u fluent-bit -n 50
```

### Проверить подключение агентов Zabbix

```bash
# Проверить из контейнера zabbix-server
docker-compose exec zabbix-server zabbix_get -s wordpress -k "system.cpu.load"
```

### Проверить логи в GrayLog

```bash
# Проверить есть ли логи в Elasticsearch
curl -s http://localhost:9200/_cat/indices | grep graylog

# Получить логи
curl -s "http://localhost:9200/graylog*/doc/_search?size=10" | jq
```

## 📈 Конфигурация агентов Zabbix

Конфигурация агентов находится в файлах:
- `nginx-custom/zabbix_agent2.conf`
- `mysql-wp/zabbix_agent2.conf`  
- `wordpress/zabbix_agent2.conf`

### Стандартные проверки
- CPU load
- Memory usage
- Disk space
- Network I/O

Можно добавить свои проверки через Custom Items в Zabbix UI.

## 📝 Логирование

### Источники логов
1. **Docker logs** - stdout/stderr контейнеров
2. **Application logs**:
   - Apache error/access logs (WordPress)
   - MySQL logs
   - Nginx logs
3. **Zabbix Agent logs**

### Формат логов
Fluent Bit собирает логи и отправляет их в GrayLog через GELF (GrayLog Extended Log Format) в JSON с полями:
- `timestamp` - время логирования
- `hostname` - хост контейнера
- `container_name` - имя контейнера
- `message` - текст логирования
- `level` - уровень (info, error и т.д.)

## 🛑 Остановка

```bash
# Остановить все контейнеры
docker-compose stop

# Остановить и удалить контейнеры
docker-compose down

# Остановить и удалить контейнеры + тома данных
docker-compose down -v
```


