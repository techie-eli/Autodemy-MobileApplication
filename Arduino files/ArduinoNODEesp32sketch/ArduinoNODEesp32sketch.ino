#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>

// --- Pins ---
#define SS_PIN 4
#define RST_PIN 15
#define BUZZER_PIN 2

LiquidCrystal_I2C lcd(0x27, 16, 2);
MFRC522 mfrc522(SS_PIN, RST_PIN);

// --- WiFi Credentials ---
const char* ssid = "HUAWEI nova 11i";
const char* password = "Password";

// --- Google Script URL ---
const char* googleScriptURL = "https://script.google.com/macros/s/AKfycbzBpGx65WmFq-_nOL32wh4WaJNsRN4aN_TUGTZJ-flx0iBYuLrBmAbAvdV9dnDP-4muaQ/exec";

// --- Cutoff for LATE ---
const int cutoffHour = 12;
const int cutoffMinute = 0;
const int cutoffSecond = 0;

// --- Status Display Variables ---
unsigned long statusDisplayStart = 0;
bool showingStatus = false;
String scrollText = "";
int scrollIndex = 0;
unsigned long scrollInterval = 100;
unsigned long lastScroll = 0;
String scannedAtTime = "";
String lastRFID = ""; // 🔒 Anti-double tap variable

void setup() {
  Serial.begin(115200);
  SPI.begin();
  mfrc522.PCD_Init();

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  lcd.init();
  lcd.backlight();
  displayReady();

  WiFi.begin(ssid, password);
  lcd.clear();
  lcd.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  lcd.clear();
  lcd.print("WiFi Connected");
  delay(1000);
  displayReady();
  Serial.print("WiFi connected with IP: ");
  Serial.println(WiFi.localIP());

  // Setup NTP time
  configTime(28800, 0, "time.google.com"); // UTC+8
  struct tm timeinfo;
  while (!getLocalTime(&timeinfo)) {
    Serial.println("Waiting for NTP...");
    delay(1000);
  }
}

void loop() {
  Serial.println("Waiting for card...");
  if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    String currentRFID = "";
    for (byte i = 0; i < mfrc522.uid.size; i++) {
      currentRFID += String(mfrc522.uid.uidByte[i], HEX);
    } 
    currentRFID.toUpperCase();

    if (currentRFID == lastRFID) {
      Serial.println("Duplicate scan ignored: " + currentRFID);
      mfrc522.PICC_HaltA();
      return;
    }

    lastRFID = currentRFID;

    String status = isLate() ? "LATE" : "PRESENT";
    String lastName = getLastName(currentRFID);
    String statusMessage = lastName + " - " + status;

    sendToGoogleSheet(currentRFID, status, lastName);

    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);

    scrollText = statusMessage + "   ";
    scrollIndex = 0;
    scannedAtTime = "Scanned at " + getFormattedTime();
    statusDisplayStart = millis();
    showingStatus = true;

    mfrc522.PICC_HaltA();
  }

  if (showingStatus) {
    if (millis() - lastScroll >= scrollInterval) {
      lastScroll = millis();
      lcd.setCursor(0, 0);
      String scrollDisplay = scrollText.substring(scrollIndex) + scrollText.substring(0, scrollIndex);
      lcd.print(scrollDisplay.substring(0, 16));
      scrollIndex = (scrollIndex + 1) % scrollText.length();
    }

    lcd.setCursor(0, 1);
    lcd.print(scannedAtTime + "    ");

    if (millis() - statusDisplayStart >= 2500) {
      showingStatus = false;
      lastRFID = ""; // ✅ Reset after message shown
      displayReady();
    }
  }
}

void sendToGoogleSheet(String rfid, String status, String lastname) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = String(googleScriptURL) + "?rfid=" + rfid + "&status=" + status + "&lastname=" + lastname;
    http.begin(url);
    int httpCode = http.GET();
    if (httpCode > 0) {
      String payload = http.getString();
      Serial.println("Google Sheet response: " + payload);
    } else {
      Serial.println("Error sending to Google Sheet");
    }
    http.end();
  } else {
    Serial.println("WiFi not connected");
  }
}

bool isLate() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return false;
  int hour = timeinfo.tm_hour;
  int minute = timeinfo.tm_min;
  int second = timeinfo.tm_sec;
  if (hour > cutoffHour) return true;
  if (hour == cutoffHour && minute > cutoffMinute) return true;
  if (hour == cutoffHour && minute == cutoffMinute && second > cutoffSecond) return true;
  return false;
}

String getFormattedTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "??:??";
  int hour = timeinfo.tm_hour;
  int minute = timeinfo.tm_min;
  int displayHour = hour % 12;
  if (displayHour == 0) displayHour = 12;
  String ampm = hour < 12 ? "AM" : "PM";
  char buf[10];
  sprintf(buf, "%d:%02d %s", displayHour, minute, ampm.c_str());
  return String(buf);
}

String getLastName(String rfid) {
  if (rfid == "477A2066") return "TestName";
  if (rfid == "3EEC4EC6") return "Albano";
  if (rfid == "1F748CD") return "Amon";
  if (rfid == "8E96E5C6") return "Bagadiong";
  if (rfid == "DE5947C6") return "Cagado";
  if (rfid == "5E4D6C6") return "Cangas";
  if (rfid == "C1A36F4A") return "Chua";
  if (rfid == "9EF8E3C6") return "Collado";
  if (rfid == "7EADEFC5") return "Corales";
  if (rfid == "EEA10C6") return "DeGuzman";
  if (rfid == "C2D9BA6D") return "DelosReyes";
  if (rfid == "1E9D43C6") return "Didulo";
  if (rfid == "BE263DC6") return "Domasig";
  if (rfid == "4E3DE0C6") return "Ebuenga";
  if (rfid == "EEEDB4C5") return "Eraldo";
  if (rfid == "8EBEE5C6") return "Ereno";
  if (rfid == "5EFCECC6") return "Erese";
  if (rfid == "4ED359C6") return "Garcia";
  if (rfid == "DE30E6C6") return "Grape";
  if (rfid == "FE17ECC6") return "Gural";
  if (rfid == "9E65F1C6") return "Hadidi";
  if (rfid == "CEABB8C5") return "Jodilla";
  if (rfid == "BEAFBC6") return "Joson";
  if (rfid == "4EC4E8C6") return "Lilam";
  if (rfid == "EE6AF7C5") return "Libre";
  if (rfid == "41AA554A") return "Magahis";
  if (rfid == "3E7DF9C5") return "Maneclang";
  if (rfid == "CE6FBFC5") return "Morallo";
  if (rfid == "7E1BEBC6") return "Pagaspas";
  if (rfid == "5E96BFC5") return "Ragadio";
  if (rfid == "CE2740C6") return "Ramilo";
  if (rfid == "4EBBFEC5") return "Revillas";
  if (rfid == "8E5F7C6") return "Rotairo";
  if (rfid == "5EE25DC6") return "Santarin";
  if (rfid == "6EB6E1C6") return "Sareno";
  if (rfid == "CE19BEC5") return "Suva";
  if (rfid == "7EA3EBC6") return "Tañag";
  if (rfid == "BEB56C6") return "ValdezAyla";
  if (rfid == "E41EBC6") return "ValdezMatt";
  if (rfid == "F1A5494A") return "Villaronte";
  if (rfid == "F113ED4A") return "SirCharles";
  if (rfid == "E3802AC") return "SirPao";
  return "Unknown";
}

void displayReady() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Scan your card!");
  lcd.setCursor(0, 1);
  lcd.print("ATTENDANCE");
}
