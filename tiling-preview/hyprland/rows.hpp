#pragma once

#include <hyprland/src/layout/algorithm/TiledAlgorithm.hpp>

#include <vector>

namespace TilingPreview {

inline constexpr auto ROWS_LAYOUT = "vertical-rows";

class Rows : public Layout::ITiledAlgorithm {
  public:
    void newTarget(SP<Layout::ITarget> target) override;
    void movedTarget(SP<Layout::ITarget> target, std::optional<Vector2D> point) override;
    void removeTarget(SP<Layout::ITarget> target) override;
    void resizeTarget(const Vector2D&, SP<Layout::ITarget>, Layout::eRectCorner) override;
    void recalculate(Layout::eRecalculateReason = Layout::RECALCULATE_REASON_UNKNOWN) override;
    void swapTargets(SP<Layout::ITarget> a, SP<Layout::ITarget> b) override;
    void moveTargetInDirection(SP<Layout::ITarget> target, Math::eDirection direction, bool silent) override;
    SP<Layout::ITarget> getNextCandidate(SP<Layout::ITarget> old) override;
    std::optional<Vector2D> predictSizeForNewTarget() override;

    CBox dropBox(const CBox& area, double y) const;

  private:
    std::vector<WP<Layout::ITarget>> targets;
};

}
