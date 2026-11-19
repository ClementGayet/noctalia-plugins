#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include <lua.hpp>
#include <stdexcept>
#include <string_view>

#include "zones.hpp"

namespace {

WP<Layout::ITarget> resizeTarget;

void finishResize() {
    if (auto target = resizeTarget.lock(); target && g_layoutManager && g_layoutManager->dragController()->target() == target)
        g_layoutManager->endDragTarget();
    resizeTarget.reset();
}

int actionResult(lua_State* lua, bool passEvent, bool requestRelease = false) {
    lua_createtable(lua, 0, 3);
    lua_pushboolean(lua, true);
    lua_setfield(lua, -2, "success");
    lua_pushboolean(lua, passEvent);
    lua_setfield(lua, -2, "pass_event");
    lua_pushboolean(lua, requestRelease);
    lua_setfield(lua, -2, "request_release");
    return 1;
}

int drag(lua_State* lua) {
    auto& action = *Config::Actions::state();
    if (action.m_bindInvocationDepth == 0)
        return luaL_error(lua, "Smart Resize must be called from a Hyprland bind");
    if (action.m_passPressed == 0) {
        finishResize();
        return actionResult(lua, false);
    }
    if (g_layoutManager->dragController()->target())
        return actionResult(lua, true);

    const auto cursor = g_pInputManager->getMouseCoordsInternal();
    const auto window = Desktop::viewState()->hitTest().windowAt(
        cursor, Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING
    );
    if (!window)
        return actionResult(lua, true);

    const auto target = window->layoutTarget();
    const auto local = cursor - window->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
    const auto size = window->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
    if (!target || size.x <= 0 || size.y <= 0)
        return actionResult(lua, true);

    static_assert(static_cast<int>(SmartResize::Top) == Layout::CORNER_TOP);
    static_assert(static_cast<int>(SmartResize::Bottom) == Layout::CORNER_BOTTOM);
    static_assert(static_cast<int>(SmartResize::Left) == Layout::CORNER_LEFT);
    static_assert(static_cast<int>(SmartResize::Right) == Layout::CORNER_RIGHT);
    const auto edge = static_cast<Layout::eRectCorner>(SmartResize::edgeAt(local.x, local.y, size.x, size.y));
    g_layoutManager->beginDragTarget(target, MBIND_RESIZE, edge);
    if (g_layoutManager->dragController()->target() != target)
        return actionResult(lua, true);

    resizeTarget = target;
    action.m_requestBindRelease = true;
    return actionResult(lua, false, true);
}

}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string_view{__hyprland_api_get_hash()} != __hyprland_api_get_client_hash())
        throw std::runtime_error("Rebuild Smart Resize against the installed Hyprland headers");
    if (!HyprlandAPI::addLuaFunction(handle, "smart_resize", "drag", drag))
        throw std::runtime_error("Could not register Smart Resize drag");
    return {"smart-resize", "Resize windows from the cursor's edge or corner zone", "clementgayet", "0.1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    finishResize();
}
