CXX ?= c++
CPPFLAGS += $(shell pkg-config --cflags hyprland)
CXXFLAGS ?= -O2 -Wall -Wextra

smart-resize.so: hyprland/plugin.cpp hyprland/zones.hpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -std=c++23 -fPIC -shared hyprland/plugin.cpp $(LDFLAGS) -o $@

.PHONY: install
install: smart-resize.so
	install -Dm755 smart-resize.so "$(or $(XDG_DATA_HOME),$(HOME)/.local/share)/hyprland/plugins/smart-resize.so"
