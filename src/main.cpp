#include <Arduino.h>
#include <U8g2lib.h>

#ifdef U8X8_HAVE_HW_SPI
#include <SPI.h>
#endif
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif

U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2_i2c(U8G2_R0, /* reset=*/ U8X8_PIN_NONE);
U8G2_SSD1306_128X64_NONAME_F_4W_HW_SPI u8g2(U8G2_R0, /* cs=*/ 4, /* dc=*/ 3, /* reset=*/ 2);

void togglePin(const int pin, const int delayMs) {
    digitalWrite(pin, HIGH);
    delay(delayMs);
    digitalWrite(pin, LOW);
    delay(delayMs);
}

int main() {
    init();
    u8g2.begin();
    u8g2_i2c.begin();

    static constexpr int pin = 5;
    pinMode(pin, OUTPUT);

    while (true) {
        u8g2.clearBuffer();
        u8g2.setFont(u8g2_font_profont10_tf);
        u8g2.drawStr(0,10, "Hey, I am running on SPI.");
        u8g2.drawStr(0,20, "I am fast as a lightning!");
        u8g2.drawStr(0,30, "But I occupy many pins :(");
        u8g2.drawStr(0,40, "What do you say, bro?");
        u8g2.sendBuffer();

        u8g2_i2c.clearBuffer();
        u8g2_i2c.setFont(u8g2_font_profont10_tf);
        u8g2_i2c.drawStr(0,10, "Hey, I am running on I2C.");
        u8g2_i2c.drawStr(0,20, "Yes, I am a bit slower...");
        u8g2_i2c.drawStr(0,30, "But I only need 2 pins :)");
        u8g2_i2c.drawStr(0,40, "Cool, right?");
        u8g2_i2c.sendBuffer();

        togglePin(pin, 200);
    }
    return 0;
}

