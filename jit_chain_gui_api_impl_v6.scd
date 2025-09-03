// jit_chain_gui_api_impl_v6.scd
// Core API glue for chain GUI in v6
// - Handles window creation, redraw, event binding, refresh logic
// - Uses ~jitGui_drawFunc for actual drawing
// - Binds to ~jitListeners for reactive updates (if present)
// - Compatible with modular chain/crossfade system

(
~jitGui_makeWindow = {
    var win, view, timer, listener, bound, scale;
    scale = ~jitGuiState[\scale] ? 1.0;
    win = Window("Chain GUI", Rect(200, 200, 760 * scale, 160 * scale));
    view = UserView(win, win.view.bounds)
        .background_(~jitGuiColors[\bg])
        .drawFunc_({ ~jitGui_drawFunc.() });
    win.view.layout_(view);
    win.front;
    ~jitGUI[\window] = win;
    ~jitGUI[\view]   = view;
    ~jitGUI[\timer]  = nil;
    ~jitGUI[\bound]  = false;
};

~jitGui_refresh = {
    var view;
    view = ~jitGUI[\view];
    if(view.notNil) { view.refresh };
};

~jitGui_bindListener = {
    if(~jitGUI[\bound].not or: { ~jitGUI[\listener].isNil }) {
        ~jitGUI[\listener] = { |phase, payload|
            ~jitGui_refresh.();
        };
        (~jitAddListener.isFunction).if({ ~jitAddListener.(~jitGUI[\listener]) });
        ~jitGUI[\bound] = true;
    };
};

~jitGui_unbindListener = {
    if(~jitGUI[\bound] and: { ~jitGUI[\listener].notNil }) {
        (~jitRemoveListener.isFunction).if({ ~jitRemoveListener.(~jitGUI[\listener]) });
        ~jitGUI[\listener] = nil;
        ~jitGUI[\bound] = false;
    };
};

~jitGui_startTimer = {
    ~jitGUI[\timer] = Routine({
        inf.do {
            ~jitGui_refresh.();
            0.2.wait;
        }
    }).play(AppClock);
};

~jitGui_stopTimer = {
    var timer;
    timer = ~jitGUI[\timer];
    if(timer.notNil) { timer.stop; ~jitGUI[\timer] = nil; };
};

~jitGui_launch = {
    ~jitGui_makeWindow.();
    // Use listeners if available, else fallback to timer
    if(~jitAddListener.isFunction) {
        ~jitGui_bindListener.();
    }{
        ~jitGui_startTimer.();
    };
};

~jitGui_close = {
    ~jitGui_unbindListener.();
    ~jitGui_stopTimer.();
    if(~jitGUI[\window].notNil) { ~jitGUI[\window].close; ~jitGUI[\window] = nil; };
    ~jitGUI[\view] = nil;
};
)