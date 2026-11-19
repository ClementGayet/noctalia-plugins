#include "placement.hpp"
#include "rows.hpp"

#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/tiled/dwindle/DwindleAlgorithm.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>

#include <limits>
#include <stdexcept>
#include <string_view>

namespace {

struct Preview {
    PHLMONITORREF monitor;
    CBox box;
};

std::optional<Preview> preview;
CHyprSignalListener dragMotion, dragEnded, renderStage;

void updatePreview(std::optional<Preview> next) {
    if (preview && next && preview->monitor == next->monitor && preview->box == next->box)
        return;
    if (preview && g_pHyprRenderer)
        g_pHyprRenderer->damageBox(preview->box);
    preview = std::move(next);
    if (preview && g_pHyprRenderer)
        g_pHyprRenderer->damageBox(preview->box);
}

double distanceTo(const CBox& box, const Vector2D& point) {
    const auto x = point.x - std::clamp(point.x, box.x, box.x + box.w);
    const auto y = point.y - std::clamp(point.y, box.y, box.y + box.h);
    return x * x + y * y;
}

std::optional<CBox> dwindleDropBox(const SP<Layout::ITarget>& moving, const SP<Layout::CSpace>& space,
                                  const Vector2D& cursor, const PHLMONITOR& monitor) {
    static auto useActive = CConfigValue<Config::INTEGER>("dwindle:use_active_for_splits");
    static auto smartSplit = CConfigValue<Config::INTEGER>("dwindle:smart_split");
    static auto preciseMove = CConfigValue<Config::INTEGER>("dwindle:precise_mouse_move");
    static auto preserveSplit = CConfigValue<Config::INTEGER>("dwindle:preserve_split");
    static auto widthMultiplier = CConfigValue<Config::FLOAT>("dwindle:split_width_multiplier");
    static auto defaultRatio = CConfigValue<Config::FLOAT>("dwindle:default_split_ratio");
    static auto splitBias = CConfigValue<Config::INTEGER>("dwindle:split_bias");

    SP<Layout::ITarget> opening;
    if (const auto active = Desktop::focusState()->window(); *useActive && active && active->mapped()) {
        const auto target = active->layoutTarget();
        if (target && target != moving && !target->floating() && target->space() == space)
            opening = target;
    }
    if (!opening) {
        double nearest = std::numeric_limits<double>::infinity();
        for (const auto& candidate : space->targets()) {
            const auto target = candidate.lock();
            if (!target || target == moving || target->floating() || !target->window() || !target->window()->mapped())
                continue;
            const auto distance = distanceTo(target->position(), cursor);
            if (distance < nearest) {
                nearest = distance;
                opening = target;
            }
        }
    }

    const auto limits = moving->maxSize();
    const auto available = opening ? opening->position().size() : monitor->m_size;
    if (limits && (limits->x < available.x || limits->y < available.y))
        return std::nullopt;
    if (!opening)
        return space->workArea();

    return TilingPreview::dwindleTile(opening->position(), cursor, *smartSplit || *preciseMove,
                                     *widthMultiplier, *defaultRatio, *splitBias != 0, *preserveSplit != 0);
}

std::optional<Preview> predictDrop() {
    const auto& drag = g_layoutManager->dragController();
    const auto moving = drag->target();
    if (!moving || drag->mode() != MBIND_MOVE || !drag->draggingTiled())
        return std::nullopt;

    const auto space = moving->space();
    const auto workspace = space ? space->workspace() : nullptr;
    const auto monitor = workspace ? workspace->m_monitor.lock() : nullptr;
    if (!monitor || !space->algorithm() || Fullscreen::controller()->hasFullscreen(workspace))
        return std::nullopt;

    const auto& layout = space->algorithm()->tiledAlgo();
    const auto cursor = g_pInputManager->getMouseCoordsInternal();
    std::optional<CBox> box;
    if (const auto rows = dynamic_cast<const TilingPreview::Rows*>(layout.get()))
        box = rows->dropBox(space->workArea(), cursor.y);
    else if (dynamic_cast<const Layout::Tiled::CDwindleAlgorithm*>(layout.get()))
        box = dwindleDropBox(moving, space, cursor, monitor);

    if (!box || box->w <= 8 || box->h <= 8)
        return std::nullopt;
    box->x += 4;
    box->y += 4;
    box->w -= 8;
    box->h -= 8;
    return Preview{monitor, *box};
}

void renderPreview(const Event::SRenderStageEvent& event) {
    if (event.stage != RENDER_POST_WINDOWS || !event.context || !preview ||
        preview->monitor.lock() != event.monitor)
        return;

    auto box = preview->box;
    box.translate(-event.monitor->m_position).scale(event.monitor->m_scale).round();
    CRectPassElement::SRectData rectangle{};
    rectangle.box = box;
    rectangle.color = CHyprColor{0.28, 0.64, 1.0, 0.33};
    rectangle.round = static_cast<int>(8 * event.monitor->m_scale);
    g_pHyprRenderer->addPassElement(event.context->get(), makeUnique<CRectPassElement>(rectangle));
}

}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string_view{__hyprland_api_get_hash()} != __hyprland_api_get_client_hash())
        throw std::runtime_error("Rebuild Tiling Preview against the installed Hyprland headers");
    if (!HyprlandAPI::addTiledAlgo(handle, TilingPreview::ROWS_LAYOUT, &typeid(TilingPreview::Rows),
                                 [] { return makeUnique<TilingPreview::Rows>(); }))
        throw std::runtime_error("Could not register the vertical rows layout");

    const auto& drag = g_layoutManager->dragController();
    dragMotion = drag->m_events.motion.listen([] { updatePreview(predictDrop()); });
    dragEnded = drag->m_events.ended.listen([] { updatePreview(std::nullopt); });
    renderStage = Event::bus()->m_events.render.stage.listen(renderPreview);
    return {"tiling-preview", "Show tiled drop placement and provide a vertical rows layout", "clementgayet", "0.1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    dragMotion.reset();
    dragEnded.reset();
    renderStage.reset();
    updatePreview(std::nullopt);
}
