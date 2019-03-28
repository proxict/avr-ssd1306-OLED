#include <Arduino.h>
#include <U8g2lib.h>

#ifdef U8X8_HAVE_HW_SPI
#include <SPI.h>
#endif
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif

U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, SCL, SDA, U8X8_PIN_NONE); // All Boards without Reset of the Display

void togglePin(const int pin, const int delayMs) {
    digitalWrite(pin, HIGH);
    delay(delayMs);
    digitalWrite(pin, LOW);
    delay(delayMs);
}

int main() {
    init();
    u8g2.begin();

    static constexpr int pin = 5;
    pinMode(pin, OUTPUT);

    while (true) {
        u8g2.clearBuffer();
        u8g2.setFont(u8g2_font_profont10_tf);
        u8g2.drawStr(0,10, "Hi mate!");
        u8g2.drawStr(0,20, "Finally got this working.");
        u8g2.drawStr(0,30, "You wouldn't believe");
        u8g2.drawStr(0,40, "where the problem was...");
        u8g2.sendBuffer();

        togglePin(pin, 200);
    }
    return 0;
}

