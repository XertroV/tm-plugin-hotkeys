
[SettingsTab name="Hotkeys" icon="Th" order="2"]
void S_MainTab() {
    Bind::DrawSettings();
}

[Setting hidden]
VirtualKey S_MenuOverrideKey = VirtualKey::Home;

[Setting hidden]
bool S_EditorNeedsOverride = true;

[Setting hidden]
bool S_DisableActivationNotifs = false;

[SettingsTab name="About" icon="InfoCircle" order="1"]
void S_AboutTab() {
    Bind::ShowAbout();
}
