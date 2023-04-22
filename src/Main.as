void Main() {
    Bind::Init();
}

bool g_UsingMenuMap = false;
bool g_InEditor = false;

void RenderEarly() {
    auto app = GetApp();
    if (app.InputPort is null) return;
    g_UsingMenuMap = app.InputPort.CurrentActionMap == "MenuInputsMap";
    g_InEditor = app.InputPort.CurrentActionMap == "CtnEditor";
    // others: Vehicle, None, SpectatorMap, CtnEditor, MenuInputsMap
}

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

const string PluginIcon = Icons::Th;
const string MenuTitle = "\\$fb0" + PluginIcon + "\\$z " + Meta::ExecutingPlugin().Name;


int g_ShiftDown = 0;
int g_CtrlDown = 0;
int g_MenuOverrideDown = 0;

/** Called whenever a key is pressed on the keyboard. See the documentation for the [`VirtualKey` enum](https://openplanet.dev/docs/api/global/VirtualKey).
*/
UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    if (key == VirtualKey::Shift) g_ShiftDown = down ? Time::Now : -1;
    else if (key == VirtualKey::Control) g_CtrlDown = down ? Time::Now : -1;

    if (key == S_MenuOverrideKey) g_MenuOverrideDown = down ? Time::Now : -1;

    return Bind::OnKeyPress(down, key);
}


void InsertToJsonArrayAt(Json::Value@ arr, Json::Value@ item, uint index) {
    if (index >= arr.Length) {
        arr.Add(item);
        return;
    }
    if (arr.Length == 1) {
        auto tmp = arr[0];
        arr[0] = item;
        arr.Add(tmp);
        return;
    }
    // start from last
    auto lastIx = arr.Length - 1;
    auto tmp = arr[lastIx];
    arr.Add(tmp);
    for (uint i = lastIx - 1; i >= index; i--) {
        arr[i + 1] = arr[i];
    }
    arr[index] = item;
}


void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::SetNextWindowSize(250, -1, UI::Cond::Always);
        UI::BeginTooltip();
        UI::TextWrapped(msg);
        UI::EndTooltip();
    }
}
