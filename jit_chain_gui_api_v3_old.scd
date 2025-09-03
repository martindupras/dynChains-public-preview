// jit_chain_gui_api_v3.scd
// Public API for compact chain GUI (v3)
// - Window title updated to indicate v3
// - Behavior unchanged (tilde globals only, var-first, no caret, no server.sync)

(
/* ---------- Public API ---------- */
~jitGuiSetSpecs = { |cur, nxt = nil|
    ~jitCurrentSpec = cur; ~jitNextSpec = nxt;
    (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh });
};

~jitGuiBind = {
    var cb;
    (~jitGUI[\bound]).if({ nil }, {
        cb = { |phase, payload| { (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh }) }.defer };
        (~jitAddListener ? { |fn| ~jitListeners = (~jitListeners ? Array.new).add(fn) }).value(cb);
        ~jitGUI[\listener] = cb; ~jitGUI[\bound] = true;
    });
};

~jitGuiUnbind = {
    var cb; cb = ~jitGUI[\listener];
    (cb.notNil and: { ~jitRemoveListener.notNil }).if({ ~jitRemoveListener.(cb) });
    ~jitGUI[\listener] = nil; ~jitGUI[\bound] = false;
};

~jitGuiStartTimer = {
    (~jitGUI[\timer].notNil).if({ ~jitGUI[\timer].stop; ~jitGUI[\timer] = nil; });
    ~jitGUI[\timer] = Routine({
        var alive; alive = true;
        while({ alive }, {
            (~jitGUI[\view].notNil).if({ { ~jitGUI[\view].refresh }.defer });
            0.25.wait;
            alive = (~jitGUI[\window].notNil) and: { ~jitGUI[\window].isClosed.not };
        });
    }).play(AppClock);
};

~jitGuiStopTimer = {
    (~jitGUI[\timer].notNil).if({ ~jitGUI[\timer].stop; ~jitGUI[\timer] = nil; });
};

~jitGuiShow = { |useListeners = true|
    var w, uv, s, colors;
    s = ~jitGuiState; colors = ~jitGuiColors;
    if(~jitGUI[\window].isNil or: { ~jitGUI[\window].isClosed }) {
        w = Window("Chain View v3", Rect(60, 60, (900 * s[\scale]).clip(500, 1600), (300 * s[\scale]).clip(200, 1400)))
        .background_(colors[\bg]);
        uv = UserView(w, w.view.bounds)
        .background_(colors[\bg])
        .clearOnRefresh_(true)
        .acceptsMouse_(false);
        ~jitGUI[\window] = w; ~jitGUI[\view] = uv;

        uv.drawFunc = { ~jitGui_drawFunc.() };

        // Use TopView hook for broad compatibility
        w.view.onResize_({ uv.bounds = w.view.bounds; uv.refresh; });

        w.view.keyDownAction = { |view, char, mods, unicode, keycode|
            var o2, s2;
            o2 = ~jitGuiState[\orient]; s2 = ~jitGuiState[\scale];
            (char == $o).if({ o2 = (o2 == \horizontal).if({ \vertical }, { \horizontal }) });
            ((char == $+) or: { char == $= }).if({ s2 = (s2 * 1.15).clip(0.8, 3.0) });
            (char == $-).if({ s2 = (s2 / 1.15).clip(0.8, 3.0) });
            (char == $n).if({ ~jitGuiState[\showNext] = ~jitGuiState[\showNext].not });
            if((o2 != ~jitGuiState[\orient]) or: { s2 != ~jitGuiState[\scale] }) {
                ~jitGuiState[\orient] = o2; ~jitGuiState[\scale] = s2;
            };
            uv.refresh;
        };

        // Bind or start timer refresh
        useListeners.if({ ~jitGuiBind.() }, { ~jitGuiStartTimer.() });

        w.onClose_({ ~jitGuiStopTimer.(); ~jitGuiUnbind.(); ~jitGUI = (~jitGUI.copy.putAll((window: nil, view: nil, timer: nil, listener: nil, bound: false))) });
        uv.refresh; w.front;
    }{
        ~jitGUI[\view].refresh; ~jitGUI[\window].front;
    };
};
)
