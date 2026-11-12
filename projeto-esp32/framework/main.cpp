#include <Arduino.h>
#include <ESP32Servo.h>
#include <stdlib.h>
#include <string.h>

constexpr int SERVO_PIN = 18;
constexpr int SERVO_MIN_ANGLE = 0;
constexpr int SERVO_MAX_ANGLE = 180;
constexpr int SERVO_HOME_ANGLE = 0;
constexpr const char* DEVICE_ID = "ESP32-001";
constexpr unsigned long SERIAL_BAUD_RATE = 115200;
constexpr size_t COMMAND_BUFFER_SIZE = 64;

Servo servo;
int currentAngle = SERVO_HOME_ANGLE;
char commandBuffer[COMMAND_BUFFER_SIZE];
size_t commandLength = 0;
bool commandOverflow = false;

void inicializarServo();
void lerSerial();
void processarComando(const char* comando);
bool moverServo(int angulo);
void mostrarStatus();
void mostrarAjuda();

void setup()
{
    Serial.begin(SERIAL_BAUD_RATE);
    inicializarServo();

    Serial.println("================================");
    Serial.println(" SISTEMA DE CONTROLE ESP32");
    Serial.println("================================");
    Serial.print("Dispositivo: ");
    Serial.println(DEVICE_ID);
    Serial.println("Servo inicializado.");
    Serial.printf("Angulo inicial: %d graus\n\n", currentAngle);
    Serial.println("Digite 'help' para visualizar");
    Serial.println("os comandos disponiveis.");
}

void loop()
{
    lerSerial();
}

void inicializarServo()
{
    servo.setPeriodHertz(50);
    servo.attach(SERVO_PIN, 500, 2400);
    servo.write(SERVO_HOME_ANGLE);
}

void lerSerial()
{
    while (Serial.available() > 0)
    {
        const char caractere = static_cast<char>(Serial.read());
        if (caractere == '\n' || caractere == '\r')
        {
            if (commandOverflow)
            {
                Serial.println("Erro: comando muito longo.");
            }
            else if (commandLength > 0)
            {
                commandBuffer[commandLength] = '\0';
                processarComando(commandBuffer);
            }
            commandLength = 0;
            commandOverflow = false;
            continue;
        }

        if (commandOverflow)
        {
            continue;
        }
        if (commandLength < COMMAND_BUFFER_SIZE - 1)
        {
            commandBuffer[commandLength++] = caractere;
        }
        else
        {
            commandOverflow = true;
        }
    }
}

static char* trimWhitespace(char* texto)
{
    while (*texto == ' ' || *texto == '\t')
    {
        ++texto;
    }
    size_t tamanho = strlen(texto);
    while (tamanho > 0 && (texto[tamanho - 1] == ' ' || texto[tamanho - 1] == '\t'))
    {
        texto[--tamanho] = '\0';
    }
    return texto;
}

void processarComando(const char* comando)
{
    char buffer[COMMAND_BUFFER_SIZE];
    strncpy(buffer, comando, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';

    char* entrada = trimWhitespace(buffer);
    if (*entrada == '\0')
    {
        return;
    }

    char* separador = entrada;
    while (*separador != '\0' && *separador != ' ' && *separador != '\t')
    {
        ++separador;
    }
    char* argumento = nullptr;
    if (*separador != '\0')
    {
        *separador++ = '\0';
        argumento = trimWhitespace(separador);
    }

    if (strcmp(entrada, "servo") == 0)
    {
        if (argumento == nullptr || *argumento == '\0')
        {
            Serial.println("Erro: informe o angulo. Exemplo: servo 90");
            return;
        }

        char* fim = nullptr;
        const long valor = strtol(argumento, &fim, 10);
        while (*fim == ' ' || *fim == '\t')
        {
            ++fim;
        }
        if (fim == argumento || *fim != '\0')
        {
            Serial.println("Erro: angulo invalido.");
            Serial.println("Informe um valor numerico entre 0 e 180.");
            return;
        }
        if (valor < SERVO_MIN_ANGLE || valor > SERVO_MAX_ANGLE)
        {
            Serial.println("Erro: o angulo deve estar entre 0 e 180 graus.");
            return;
        }
        if (moverServo(static_cast<int>(valor)))
        {
            Serial.printf("Servo movimentado para %ld graus.\n", valor);
        }
        else
        {
            Serial.println("Erro: servo nao inicializado.");
        }
        return;
    }

    if (argumento != nullptr && *argumento != '\0')
    {
        Serial.println("Erro: este comando nao aceita argumentos.");
        return;
    }
    if (strcmp(entrada, "status") == 0)
    {
        mostrarStatus();
    }
    else if (strcmp(entrada, "help") == 0)
    {
        mostrarAjuda();
    }
    else if (strcmp(entrada, "home") == 0)
    {
        Serial.printf("Retornando servo para a posicao inicial: %d graus.\n", SERVO_HOME_ANGLE);
        if (!moverServo(SERVO_HOME_ANGLE))
        {
            Serial.println("Erro: servo nao inicializado.");
        }
    }
    else
    {
        Serial.println("Comando desconhecido.");
        Serial.println("Digite 'help' para visualizar os comandos disponiveis.");
    }
}

bool moverServo(int angulo)
{
    if (angulo < SERVO_MIN_ANGLE || angulo > SERVO_MAX_ANGLE || !servo.attached())
    {
        return false;
    }
    servo.write(angulo);
    currentAngle = angulo;
    return true;
}

void mostrarStatus()
{
    Serial.println("=== STATUS ===");
    Serial.printf("Dispositivo: %s\n", DEVICE_ID);
    Serial.printf("Servo: %s\n", servo.attached() ? "conectado" : "desconectado");
    Serial.printf("Angulo atual: %d graus\n", currentAngle);
    Serial.printf("Sistema: %s\n", servo.attached() ? "OK" : "ERRO");
    Serial.println("==============");
}

void mostrarAjuda()
{
    Serial.println("Comandos disponiveis:");
    Serial.println();
    Serial.println("servo <angulo>  - Move o servo para o angulo informado");
    Serial.println("home            - Retorna o servo para a posicao inicial");
    Serial.println("status          - Mostra o estado atual");
    Serial.println("help            - Mostra esta ajuda");
}
