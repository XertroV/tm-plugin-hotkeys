namespace Bind {
    const string BindingsJsonFile = IO::FromStorageFolder("bindings.json");
    Json::Value@ _db = IO::FileExists(BindingsJsonFile) ? Json::FromFile(BindingsJsonFile) : Json::Array();
    bool[] keysWithBindings = array<bool>(256);
    void SaveDB() {
        trace('Saving Bindings DB');
        Json::ToFile(BindingsJsonFile, _db);
    }
    void Init() {
        @_db = IO::FileExists(BindingsJsonFile) ? Json::FromFile(BindingsJsonFile) : Json::Array();
        if (_db is null || _db.GetType() != Json::Type::Array)
            @_db = Json::Array();
        UpdateKeysWithBindings();
    }

    void UpdateKeysWithBindings() {
        for (uint i = 0; i < keysWithBindings.Length; i++) {
            keysWithBindings[i] = false;
        }
        for (uint i = 0; i < _db.Length; i++) {
            auto item = _db[i];
            keysWithBindings[int(item['key'])] = true;
        }
    }

    void DrawSettings() {
        UI::AlignTextToFramePadding();
        UI::Text("Menu Override Key: " + tostring(S_MenuOverrideKey));
        AddSimpleTooltip("In menus (or while typing), you need to hold down this key while you trigger a hotkey.");
        UI::SameLine();
        if (UI::Button("Rebind##overridekey")) {
            StartRebind("Menu Override Key");
        }
        bool amDone = (rebindAborted || gotNextKey) && !rebindInProgress && activeKeyName == "Menu Override Key";
        if (amDone && gotNextKey) {
            ResetBindingState();
            S_MenuOverrideKey = tmpKey;
        }
        UI::SameLine();
        S_EditorNeedsOverride = UI::Checkbox("Editor requires override, too?", S_EditorNeedsOverride);

        UI::Separator();

        S_DisableActivationNotifs= UI::Checkbox("Disable Activation Notifications", S_DisableActivationNotifs);

        UI::Separator();

        DrawAddPluginDropdown();

        if (UI::BeginTable("bindings", 7, UI::TableFlags::SizingStretchSame)) {
            UI::TableSetupColumn("##status", UI::TableColumnFlags::WidthFixed, 24 * UI_SCALE);
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch, 1.1);
            UI::TableSetupColumn("Binding", UI::TableColumnFlags::WidthStretch, .5f);
            UI::TableSetupColumn("Modifiers", UI::TableColumnFlags::WidthFixed, 70 * UI_SCALE);
            UI::TableSetupColumn("Action", UI::TableColumnFlags::WidthFixed, 140 * UI_SCALE);
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 100 * UI_SCALE);
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 100 * UI_SCALE);
            UI::TableHeadersRow();

            for (uint i = 0; i < _db.Length; i++) {
                auto item = _db[i];
                UI::PushID(item['nonce']);
                item['key'] = int(DrawKeyBinding(string(item['name']) + "##" + string(item['nonce']), VirtualKey(int(item['key'])), item, i));
                // item['enabled'] = DrawKeyBindSwitch("show-hide", bool(item['enabled']));
                UI::PopID();
            }

            UI::EndTable();
        }
        UI::Separator();
        if (rebindInProgress) {
            UI::Markdown("# Press a key to bind, or Esc to cancel.");
        } else {
            // ShowAbout();
        }
    }

    Meta::Plugin@ selectedPlugin = null;
    string pluginFilter = "";

    void DrawAddPluginDropdown() {
        UI::SetNextItemWidth(250);
        pluginFilter = UI::InputText("Filter Plugins by Name/Category", pluginFilter);
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("Plugins", selectedPlugin is null ? "" : selectedPlugin.Name)) {
            auto plugins = Meta::AllPlugins();
            string lastCategory;
            for (uint i = 0; i < plugins.Length; i++) {
                auto item = plugins[i];
                if (item is null) {
                    warn('plugin null?');
                    continue;
                }

                if (pluginFilter.Length > 0 && (
                    !item.Name.ToLower().Contains(pluginFilter.ToLower())
                    && !item.Category.ToLower().Contains(pluginFilter.ToLower())
                ))
                    continue;

                // if (item.Category != lastCategory) {
                //     lastCategory = item.Category;
                //     UI::BeginDisabled();
                //     UI::Selectable("― "+lastCategory+" ―", false);
                //     UI::EndDisabled();
                // }
                if (UI::Selectable(item.Name + "  \\$888("+item.Category+")", selectedPlugin !is null && item.ID == selectedPlugin.ID)) {
                    @selectedPlugin = item;
                }
            }
            UI::EndCombo();
        }
        UI::BeginDisabled(selectedPlugin is null);
        if (UI::Button("Add Binding")) {
            AddBindingFor(selectedPlugin);
            @selectedPlugin = null;
        }
        UI::SameLine();
        if (UI::Button("Reset")) {
            @selectedPlugin = null;
            pluginFilter = "";
        }
        UI::EndDisabled();
    }

    void AddBindingFor(Meta::Plugin@ plugin) {
        auto entry = DefaultBindingFor(plugin);
        uint i = 0;
        for (; i < _db.Length; i++) {
            if (string(_db[i]['name']) <= plugin.Name) continue;
            InsertToJsonArrayAt(_db, entry, i);
            break;
        }
        if (i == _db.Length) {
            _db.Add(entry);
        }
        OnChange();
    }

    void OnChange() {
        UpdateKeysWithBindings();
        SaveDB();
    }

    enum Actions {
        Disable = 0,
        Enable = 1,
        Toggle = 2,
        Group_Disable = 4,
        Group_Enable = 5,
        Group_Toggle = 6,
        Group_ToggleInverse = 7
    }

    Json::Value@ DefaultBindingFor(Meta::Plugin@ plugin) {
        auto j = Json::Object();
        j['name'] = plugin.Name;
        j['nonce'] = tostring(Time::Now) + Math::Rand(10000, 99999);
        j['id'] = plugin.ID;
        j['siteid'] = plugin.SiteID;
        j['key'] = int(VirtualKey::F13);
        j['enabled'] = true;
        j['action'] = int(Actions::Toggle);
        j['+ctrl'] = false;
        j['+shift'] = false;
        return j;
    }

    string activeKeyName;
    VirtualKey tmpKey;
    bool gotNextKey = false;
    bool rebindInProgress = false;
    bool rebindAborted = false;

    VirtualKey DrawKeyBinding(const string &in name, VirtualKey &in valIn, Json::Value@ binding, int index) {
        // string nameId =
        bool amActive = rebindInProgress && activeKeyName == name;
        bool amDone = (rebindAborted || gotNextKey) && !rebindInProgress && activeKeyName == name;
        auto pluginId = string(binding['id']);
        auto plugin = Meta::GetPluginFromID(pluginId);

        UI::PushID(name);

        UI::TableNextRow();

        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        UI::Text(plugin is null
            ? "\\$888??"
            : plugin.Enabled
                ? Icons::Check
                : Icons::Times
            );
        AddSimpleTooltip(plugin is null ? "Unknown Plugin " : plugin.Enabled ? "Plugin Enabled" : "Plugin Disabled");

        UI::TableNextColumn();
        UI::Text((bool(binding['enabled']) ? "" : "\\$888") + name.Split("##")[0]);

        UI::TableNextColumn();
        UI::Text(tostring(valIn));

        UI::TableNextColumn();
        bool preShift = bool(binding.Get('+shift', false));
        bool preCtrl = bool(binding.Get('+ctrl', false));
        binding['+shift'] = UI::Checkbox("##shift", bool(binding.Get('+shift', false)));
        UI::SameLine();
        AddSimpleTooltip("+ Shift");
        binding['+ctrl'] = UI::Checkbox("##ctrl", bool(binding.Get('+ctrl', false)));
        AddSimpleTooltip("+ Ctrl");
        bool changed = preShift != bool(binding['+shift'])
            || preCtrl != bool(binding['+ctrl']);
        if (changed) {
            startnew(OnChange);
        }


        UI::TableNextColumn();
        Actions currAction = Actions(int(binding['action']));
        UI::SetNextItemWidth(140);
        if (UI::BeginCombo("##action", tostring(currAction))) {
            for (int i = 0; i < 8; i++) {
                if (i == 3) continue;
                if (UI::Selectable(tostring(Actions(i)), i == currAction)) {
                    binding['action'] = i;
                    startnew(OnChange);
                }
            }
            UI::EndCombo();
        }

        UI::TableNextColumn();
        UI::BeginDisabled(rebindInProgress);
        if (UI::Button("Rebind")) StartRebind(name);
        UI::SameLine();
        if (UI::Button(Icons::Trash)) startnew(RemoveBindingAt, index);
        UI::EndDisabled();

        UI::TableNextColumn();
        bool val = bool(binding['enabled']);
        auto new = UI::Checkbox("Enabled", val);
        if (new != val) startnew(OnChange);
        binding['enabled'] = new;

        UI::PopID();
        // if (amActive) {
            // UI::SameLine();
            // UI::Text("Press a key to bind, or Esc to cancel.");
        // }
        if (amDone) {
            if (gotNextKey) {
                ResetBindingState();
                startnew(OnChange);
                return tmpKey;
            } else {
                // UI::SameLine();
                UI::Text("\\$888Rebind aborted.");
            }
        }
        return valIn;
    }

    void RemoveBindingAt(int64 index) {
        _db.Remove(index);
        OnChange();
    }

    void ResetBindingState() {
        rebindInProgress = false;
        activeKeyName = "";
        gotNextKey = false;
        rebindAborted = false;
    }

    void StartRebind(const string &in name) {
        if (rebindInProgress) return;
        rebindInProgress = true;
        activeKeyName = name;
        gotNextKey = false;
        rebindAborted = false;
    }

    void ReportRebindKey(VirtualKey key) {
        if (!rebindInProgress) return;
        if (key == VirtualKey::Escape) {
            rebindInProgress = false;
            rebindAborted = true;
        } else {
            rebindInProgress = false;
            gotNextKey = true;
            tmpKey = key;
        }
    }


    void ShowAbout() {
        UI::Markdown("""
 ## Bindings

 Bindings let you perform an action on a plugin when a key is pressed (i.e., hotkeys).

 ## Actions

 Actions are Toggle, Enable, Disable, Group_Toggle, Group_ToggleInverse, Group_Enable, Group_Disable.

 The Group_ actions will ensure that all plugins with that binding are synchronized.
 The binding determines if a plugin is in a group or not.

 The **first** plugin with a Toggle action in a group determines which way the rest of the plugins will be toggled.
 This way, everything will be synchronized after 1 trigger, and if it's the wrong way, just hit it again and you should be good.

 If the first plugin is enabled, then it will be disabled along with all the other Group_Toggle plugins.
 If a binding is set to Group_ToggleInverse, then it will be enabled when the group is toggled off, and disabled when the group is toggled on.

 **Group actions have priority over non-group actions.**

 ### Menus & Typing

 In order not to toggle hotkeys when typing, they will not be active while typing or in menus unless another key is held down.
 By default this is the Home key.

        """);
    }


    /**
     * Main logic
     */
    bool ctrlActive = false;
    bool shiftActive = false;
    UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
        if (!down) return UI::InputBlocking::DoNothing;
        // rebind has priority if active
        if (rebindInProgress) {
            ReportRebindKey(key);
            return UI::InputBlocking::Block;
        }
        // if we don't have a binding for this key, exit befor checking anything expensive
        if (!keysWithBindings[key]) return UI::InputBlocking::DoNothing;

        // if we're in the menu/editor input maps, make sure we really want to trigger key bindings
        if (g_MenuOverrideDown <= 0
            && (g_UsingMenuMap || (S_EditorNeedsOverride && g_InEditor))
        ) {
            trace('not reacting to hotkey b/c in menu/editor');
            return UI::InputBlocking::DoNothing;
        }


        // get a list of plugins to perform an action on
        auto toggleList = GetPluginListFor(key);
        if (toggleList.Length == 0) return UI::InputBlocking::DoNothing;

        trace('Hotkeys for nb plugins: ' + toggleList.Length);

        dictionary groupToggleStatus;
        dictionary pluginDestStatus;
        dictionary pluginGroupStatus;
        for (uint i = 0; i < toggleList.Length; i++) {
            auto item = toggleList[i];
            Actions action = Actions(int(item['action']));
            // not in a group -- handle individually
            if (action < 4) {
                pluginDestStatus[item['id']] = CalcPluginActionResult(action, item);
            } else {
                // the toggle actions
                if (action >= 6) {
                    string groupId = tostring(int(item['key'])) + bool(item['+ctrl']) + bool(item['+shift']);
                    if (!groupToggleStatus.Exists(groupId)) {
                        groupToggleStatus[groupId] = CalcPluginActionResult(Actions::Toggle, item);
                    }
                    pluginGroupStatus[item['id']] = (action == Actions::Group_ToggleInverse) ^^ bool(groupToggleStatus[groupId]);
                } else {
                    pluginGroupStatus[item['id']] = action == Actions::Group_Enable;
                }
            }
        }
        string[] logs = {};
        SetPluginsEnabled(pluginDestStatus, logs);
        SetPluginsEnabled(pluginGroupStatus, logs);
        string mainMsg = string::Join(logs, "\n");
        if (!S_DisableActivationNotifs) {
            Notify(mainMsg);
        }
        trace("  >>  Set Plugins On/Off:\n" + mainMsg);
        return UI::InputBlocking::DoNothing;
    }

    void SetPluginsEnabled(dictionary@ idToStatus, string[]@ logs) {
        auto plugins1= idToStatus.GetKeys();
        for (uint i = 0; i < plugins1.Length; i++) {
            auto p = Meta::GetPluginFromID(plugins1[i]);
            if (p is null) continue;
            bool dest = bool(idToStatus[plugins1[i]]);
            bool currEnabled = p.Enabled;
            if (dest != currEnabled) {
                logs.InsertLast("Setting " + p.Name + " to " + (dest ? "Enabled" : "Disabled"));
                if (dest) p.Enable();
                else p.Disable();
            }
        }
    }

    bool CalcPluginActionResult(Actions action, Json::Value@ binding) {
        if (action >= 4) throw('group action passed to calc individual action');
        if (action < 2) {
            return action == Actions::Enable;
        }
        auto p = Meta::GetPluginFromID(binding['id']);
        if (p is null) return false;
        return !p.Enabled;
    }

    Json::Value@[]@ GetPluginListFor(VirtualKey key) {
        ctrlActive = Time::Now - g_CtrlDown < 600;
        shiftActive = Time::Now - g_ShiftDown < 600;
        array<Json::Value@> ret;
        for (uint i = 0; i < _db.Length; i++) {
            auto item = _db[i];
            if (MatchKeyPress(item, key)) {
                ret.InsertLast(item);
            }
        }
        return ret;
    }

    bool MatchKeyPress(Json::Value@ item, VirtualKey key) {
        if (!bool(item['enabled'])) return false;
        bool needCtrl = bool(item['+ctrl']);
        bool needShift = bool(item['+shift']);
        return int(item['key']) == key
            && (!needCtrl || ctrlActive)
            && (!needShift || shiftActive)
            ;
    }
}
