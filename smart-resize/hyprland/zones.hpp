#pragma once

#include <algorithm>
#include <array>
#include <cstdint>

namespace SmartResize {

enum Edge : std::uint8_t {
    Top = 1 << 0,
    Bottom = 1 << 1,
    Left = 1 << 2,
    Right = 1 << 3,
};

constexpr Edge edgeAt(double x, double y, double width, double height) {
    const auto horizontal = x < width / 3 ? Left : x >= width * 2 / 3 ? Right : Edge{};
    const auto vertical = y < height / 3 ? Top : y >= height * 2 / 3 ? Bottom : Edge{};
    if (horizontal || vertical)
        return static_cast<Edge>(horizontal | vertical);

    // The center falls back to the closest edge in logical pixels.
    const std::array distances{x, width - x, y, height - y};
    constexpr std::array edges{Left, Right, Top, Bottom};
    return edges[std::ranges::min_element(distances) - distances.begin()];
}

}
