#!/bin/bash

# Graylog Initialization Script
# Этот скрипт настраивает GrayLog inputs и collectors для сбора логов Docker контейнеров

set -e

GRAYLOG_URL="http://localhost:9000"
GRAYLOG_USER="admin"
GRAYLOG_PASS="admin"
MAX_ATTEMPTS=30
ATTEMPT=0

echo "🔄 Ожидание запуска Graylog..."
while ! curl -s "$GRAYLOG_URL/api/system/info" > /dev/null 2>&1; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo "❌ GrayLog не запустился за $MAX_ATTEMPTS попыток"
        exit 1
    fi
    echo "  Попытка $ATTEMPT/$MAX_ATTEMPTS..."
    sleep 2
done

echo "✅ GrayLog запущен!"

# Функция для создания input
create_gelf_input() {
    local INPUT_NAME=$1
    local PORT=$2
    
    echo "📝 Создание GELF input: $INPUT_NAME на порту $PORT..."
    
    curl -s -X POST "$GRAYLOG_URL/api/system/inputs" \
        -H "Content-Type: application/json" \
        -u "$GRAYLOG_USER:$GRAYLOG_PASS" \
        -d @- <<EOF
{
  "type": "org.graylog2.inputs.gelf.gelf_udp",
  "title": "$INPUT_NAME",
  "global": true,
  "configuration": {
    "bind_address": "0.0.0.0",
    "port": $PORT,
    "recv_buffer_size": 262144,
    "use_null_delimiter": false
  }
}
EOF
    echo ""
}

# Функция для создания syslog input
create_syslog_input() {
    local INPUT_NAME=$1
    local PORT=$2
    
    echo "📝 Создание Syslog input: $INPUT_NAME на порту $PORT..."
    
    curl -s -X POST "$GRAYLOG_URL/api/system/inputs" \
        -H "Content-Type: application/json" \
        -u "$GRAYLOG_USER:$GRAYLOG_PASS" \
        -d @- <<EOF
{
  "type": "org.graylog2.inputs.syslog.udp.SyslogUDPInput",
  "title": "$INPUT_NAME",
  "global": true,
  "configuration": {
    "bind_address": "0.0.0.0",
    "port": $PORT,
    "recv_buffer_size": 262144,
    "protocol": "rfc3164",
    "expand_structured_data": false
  }
}
EOF
    echo ""
}

# Создаем inputs
create_gelf_input "Docker Logs (Fluent Bit)" 12201
create_syslog_input "System Syslog" 5140

echo "✅ GrayLog успешно инициализирован!"
echo ""
echo "🌐 Доступ к GrayLog:"
echo "   URL: http://localhost:9000"
echo "   User: admin"
echo "   Pass: admin"
echo ""
echo "📊 Откройте браузер и перейдите на http://localhost:9000/system/inputs"
echo "    чтобы проверить созданные inputs"
