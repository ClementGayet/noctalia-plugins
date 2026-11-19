CXX ?= c++
CPPFLAGS += $(shell pkg-config --cflags hyprland)
CXXFLAGS ?= -O2 -Wall -Wextra

tiling-preview.so: hyprland/plugin.cpp hyprland/rows.cpp hyprland/rows.hpp hyprland/placement.hpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -std=c++23 -fPIC -shared hyprland/plugin.cpp hyprland/rows.cpp $(LDFLAGS) -o $@

.PHONY: install
install: tiling-preview.so
	install -Dm755 tiling-preview.so "$(or $(XDG_DATA_HOME),$(HOME)/.local/share)/hyprland/plugins/tiling-preview.so"
