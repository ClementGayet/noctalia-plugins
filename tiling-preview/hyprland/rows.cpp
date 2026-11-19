#include "rows.hpp"
#include "placement.hpp"

#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>

using namespace TilingPreview;

void Rows::newTarget(SP<Layout::ITarget> target) {
    targets.emplace_back(target);
    recalculate();
}

void Rows::movedTarget(SP<Layout::ITarget> target, std::optional<Vector2D> point) {
    if (g_layoutManager->dragController()->wasDraggingWindow())
        point = g_pInputManager->getMouseCoordsInternal();
    const auto parent = m_parent.lock();
    if (!point || !parent || !parent->space()) {
        newTarget(target);
        return;
    }

    std::erase_if(targets, [](const auto& item) { return item.expired(); });
    const auto index = insertionRow(parent->space()->workArea(), point->y, targets.size() + 1);
    targets.insert(targets.begin() + index, target);
    recalculate();
}

void Rows::removeTarget(SP<Layout::ITarget> target) {
    std::erase_if(targets, [&target](const auto& item) { return item.expired() || item.lock() == target; });
    recalculate();
}

void Rows::resizeTarget(const Vector2D&, SP<Layout::ITarget>, Layout::eRectCorner) {
    // Every row has the same height.
}

void Rows::recalculate(Layout::eRecalculateReason) {
    const auto parent = m_parent.lock();
    const auto space = parent ? parent->space() : nullptr;
    if (!space)
        return;
    std::erase_if(targets, [](const auto& item) { return item.expired(); });
    for (std::size_t i = 0; i < targets.size(); ++i)
        targets[i]->setPositionGlobal(rowAt(space->workArea(), i, targets.size()));
}

void Rows::swapTargets(SP<Layout::ITarget> a, SP<Layout::ITarget> b) {
    const auto first = std::ranges::find_if(targets, [&a](const auto& item) { return item.lock() == a; });
    const auto second = std::ranges::find_if(targets, [&b](const auto& item) { return item.lock() == b; });
    if (first != targets.end() && second != targets.end())
        std::iter_swap(first, second);
    else if (first != targets.end())
        *first = b;
    else if (second != targets.end())
        *second = a;
    recalculate();
}

void Rows::moveTargetInDirection(SP<Layout::ITarget> target, Math::eDirection direction, bool) {
    const auto item = std::ranges::find_if(targets, [&target](const auto& row) { return row.lock() == target; });
    if (item == targets.end())
        return;
    if (direction == Math::DIRECTION_UP && item != targets.begin())
        std::iter_swap(item, std::prev(item));
    else if (direction == Math::DIRECTION_DOWN && std::next(item) != targets.end())
        std::iter_swap(item, std::next(item));
    else
        return;
    recalculate();
}

SP<Layout::ITarget> Rows::getNextCandidate(SP<Layout::ITarget> old) {
    if (targets.empty())
        return nullptr;
    const auto item = std::ranges::find_if(targets, [&old](const auto& row) { return row.lock() == old; });
    if (item == targets.end())
        return targets.back().lock();
    if (std::next(item) != targets.end())
        return std::next(item)->lock();
    return item == targets.begin() ? nullptr : std::prev(item)->lock();
}

std::optional<Vector2D> Rows::predictSizeForNewTarget() {
    const auto parent = m_parent.lock();
    const auto space = parent ? parent->space() : nullptr;
    if (!space)
        return std::nullopt;
    return dropBox(space->workArea(), space->workArea().y).size();
}

CBox Rows::dropBox(const CBox& area, double y) const {
    const std::size_t count = std::ranges::count_if(targets, [](const auto& item) { return !item.expired(); }) + 1;
    return rowAt(area, insertionRow(area, y, count), count);
}
