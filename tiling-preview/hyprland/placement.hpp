#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace TilingPreview {

template<typename Box>
Box rowAt(const Box& area, std::size_t index, std::size_t count) {
    const double height = area.h / count;
    return {area.x, area.y + index * height, area.w, height};
}

template<typename Box>
std::size_t insertionRow(const Box& area, double y, std::size_t count) {
    if (area.h <= 0)
        return count - 1;
    const double position = (y - area.y) * count / area.h;
    return static_cast<std::size_t>(std::clamp(position, 0.0, static_cast<double>(count - 1)));
}

template<typename Box, typename Point>
Box dwindleTile(const Box& box, const Point& cursor, bool precise, double widthMultiplier,
               double ratio, bool biasCurrent, bool keepAxis) {
    const double x = cursor.x - (box.x + box.w / 2);
    const double y = cursor.y - (box.y + box.h / 2);
    const bool vertical = precise ? std::abs(y) * box.w >= std::abs(x) * box.h
        : (keepAxis ? box.w <= box.h * widthMultiplier : box.h * widthMultiplier > box.w);
    const bool first = precise ? (vertical ? y <= 0 : x <= 0)
        : (box.w > box.h * widthMultiplier ? x < 0 : y < 0);
    ratio = std::clamp(ratio, 0.1, 1.9);
    if (biasCurrent && first)
        ratio = 2 - ratio;
    const double fraction = ratio / 2;
    if (vertical) {
        const double split = box.h * fraction;
        return {box.x, box.y + (first ? 0 : split), box.w, first ? split : box.h - split};
    }
    const double split = box.w * fraction;
    return {box.x + (first ? 0 : split), box.y, first ? split : box.w - split, box.h};
}

}
