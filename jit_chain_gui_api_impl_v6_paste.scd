// jit_chain_gui_api_impl_v6.scd
// Core API glue for chain GUI in v6
// - Handles window creation, redraw, event binding, refresh logic
// - Uses ~jitGui_drawFunc for actual drawing
// - Binds to ~jitListeners for reactive updates (if present)
// - Compatible with modular chain/crossfade system
(
~jitGui_makeWindow = {
    var win, view, scale, title, bg, s;

    // Ensure globals exist with fallbacks
    ~jitGUI       = (~jitGUI ? IdentityDictionary.new);
    ~jitGuiState  = (~jitGuiState ? (scale: 1.0, orient: \horizontal, showNext: true));
    ~jitGuiColors = (~jitGuiColors ? (bg: Color(0.12, 0.12, 0.12), text: Color(0.9, 0.9, 0.9)));

    s = ~jitGuiState;
    scale = (s[\scale] ? 1.0).asFloat.clip(0.5, 3.0);

    // Global version label from config (fallback to "v6")
    title = "JIT Chain (" ++ (~displayVersion ? "v6") ++ ")";
    bg = ~jitGuiColors[\bg];

    win = Window(title, Rect(200, 200, 760 * scale, 160 * scale));
    view = UserView(win, win.view.bounds)
        .background_(bg)
        .drawFunc_({ (~jitGui_drawFunc ? { /* no-op */ }).value });

    // Resize: keep view full-window and refresh
    win.view.onResize_({
        view.bounds = win.view.bounds;
        view.refresh;
    });

    win.front;

    ~jitGUI[\window] = win;
    ~jitGUI[\view]   = view;
    ~jitGUI[\timer]  = nil;
    ~jitGUI[\bound]  = false;

    // Close hook: use ~jitGui_close for consistent cleanup
    win.onClose_({ { ~jitGui_close.() }.defer });
};

~jitGui_refresh = {
    var view;
    view = ~jitGUI[\view];
    if(view.notNil) { view.refresh };
};

~jitGui_bindListener = {
    var cb;
    if(~jitGUI[\bound].not or: { ~jitGUI[\listener].isNil }) {
        cb = { |phase, payload|
            var once;
            once = ~jitGuiRefreshOnce;
            (once.notNil).if({ once.() }, { ~jitGui_refresh.() });
        };
        (~jitAddListener.isFunction).if({ ~jitAddListener.(cb) });
        ~jitGUI[\listener] = cb; ~jitGUI[\bound] = true;
    };
};

~jitGui_unbindListener = {
    var cb;
    if(~jitGUI[\bound] and: { ~jitGUI[\listener].notNil }) {
        cb = ~jitGUI[\listener];
        (~jitRemoveListener.isFunction).if({ ~jitRemoveListener.(cb) });
        ~jitGUI[\listener] = nil;
        ~jitGUI[\bound] = false;
    };
};

~jitGui_startTimer = {
    var timer;
    timer = Routine({
        var once;
        inf.do({
            once = ~jitGuiRefreshOnce;
            (once.notNil).if({ once.() }, { ~jitGui_refresh.() });
            0.2.wait;
        })
    }).play(AppClock);
    ~jitGUI[\timer] = timer;
};

~jitGui_stopTimer = {
    var timer;
    timer = ~jitGUI[\timer];
    if(timer.notNil) { timer.stop; ~jitGUI[\timer] = nil; };
};

~jitGui_launch = {
    var win;
    ~jitGUI = (~jitGUI ? IdentityDictionary.new);
    win = ~jitGUI[\window];

    if(win.isNil or: { win.isClosed }) {
        ~jitGui_makeWindow.();
        // Prefer listeners if available, fallback to timer
        if(~jitAddListener.isFunction) {
            ~jitGui_bindListener.();
        }{
            ~jitGui_startTimer.();
        };
    }{
        ~jitGUI[\view].refresh;
        win.front;
    };
};

~jitGui_close = {
    var win;
    ~jitGui_unbindListener.();
    ~jitGui_stopTimer.();
    win = ~jitGUI[\window];
    if(win.notNil) { win.close; ~jitGUI[\window] = nil; };
    ~jitGUI[\view] = nil;
};

// ---- Compatibility aliases (v4 -> v6) ----
~jitChainGuiWindow = ~jitChainGuiWindow ? { ~jitGui_launch.() };
~jitChainGuiShow   = ~jitChainGuiShow   ? { ~jitGui_launch.() };
~jitGuiShow        = ~jitGuiShow        ? { ~jitGui_launch.() };
~jitGuiBind        = ~jitGuiBind        ? { ~jitGui_bindListener.() };
~jitGuiUnbind      = ~jitGuiUnbind      ? { ~jitGui_unbindListener.() };
~jitGuiStartTimer  = ~jitGuiStartTimer  ? { ~jitGui_startTimer.() };
~jitGuiStopTimer   = ~jitGuiStopTimer   ? { ~jitGui_stopTimer.() };
)
