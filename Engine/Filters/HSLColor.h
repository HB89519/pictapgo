#include <cmath>
#include <iosfwd>

struct HSLColor {
    HSLColor(float h, float s, float l) : h(h), s(s), l(l) {}
    HSLColor(CGColorRef rgb);
    float h, s, l;   // all normalized in range [0.0,1.0]
};

std::ostream& operator<<(std::ostream&, const HSLColor&);

inline bool almostEqual(float v1, float v2) {
    const float EPSILON = 1/255.0f;
    return (std::fabs(v1 - v2) < EPSILON);
}

inline float hueToRGB(float m1, float m2, float h) {
    if (h < 0.0f) h += 1.0f;
    if (h > 1.0f) h -= 1.0f;
    if (h < 1.0f / 6.0f) return (m1 + (m2 - m1) * h * 6.0f);
    if (h < 1.0f / 2.0f) return m2;
    if (h < 2.0f / 3.0f) return (m1 + (m2 - m1) * ((2.0f / 3.0f) - h) * 6.0f);
    return m1;
}

CGColorRef CGColorCreateWithHSLColor(const HSLColor& hsl) {
    CGFloat ch[4];
    ch[0] = ch[1] = ch[2] = 0.0, ch[3] = 1.0;
    if (almostEqual(hsl.s, 0.0f)) {
        ch[0] = ch[1] = ch[2] = hsl.l;
    } else {
        float m2;
        if (hsl.l <= 0.5f) {
            m2 = hsl.l * (1.0f + hsl.s);
        } else {
            m2 = hsl.l + hsl.s - hsl.l * hsl.s;
        }

        float m1 = 2.0f * hsl.l - m2;

        ch[0] = hueToRGB(m1, m2, hsl.h + (1.0f / 3.0f));
        ch[1] = hueToRGB(m1, m2, hsl.h);
        ch[2] = hueToRGB(m1, m2, hsl.h - (1.0f / 3.0f));
    }
    CGColorSpaceRef dRGB = CGColorSpaceCreateDeviceRGB();
    CGColorRef result = CGColorCreate(dRGB, ch);
    CGColorSpaceRelease(dRGB);

    return result;
}

inline HSLColor::HSLColor(CGColorRef rgb) {
    const CGFloat* ch = CGColorGetComponents(rgb);

    const float maxVal = std::max(std::max(ch[0], ch[1]), ch[2]);
    const float minVal = std::min(std::min(ch[0], ch[1]), ch[2]);

    h = 0.0f;
    s = 0.0f;
    l = (maxVal + minVal) / 2.0f;

    const float delta = (maxVal - minVal);

    if (almostEqual(delta, 0.0f)) return;

    if (l <= 0.5f) {
        s = delta / (maxVal + minVal);
    } else if (l < 1.0f) {
        s = delta / (2.0f - (maxVal + minVal));
    }

    if (almostEqual(ch[0], maxVal)) {
        float tempHue = (ch[1] - ch[2]) / delta;
        if (tempHue < 0.0f) {
            tempHue += 6.0f;
        }
        if (tempHue > 6.0f) {
            tempHue -= 6.0f;
        }
        h = tempHue;
    } else if (almostEqual(ch[1], maxVal)) {
        h = 2.0f + (ch[2] - ch[0]) / delta;
    } else if (almostEqual(ch[2], maxVal)){
        h = 4.0f + (ch[0] - ch[1]) / delta;
    }

    h /= 6.0f;
}
