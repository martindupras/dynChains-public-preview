// jit_chain_gui_api_impl_v4.scd
// Public API for compact chain GUI (v4)
// - Window title indicates v4
// - Buttons call v4 CF helpers (~jitCFPreview / ~jitCFSwitchNow / ~jitCFSwitchIn)
// - Uses ~jitGuiRefreshOnce() when available (no GUI floods)
// - Tilde-globals only; var-first; caret-free; no server.sync; no try/protect

(
/* ---------- Public API ---------- */
~jitGuiSetSpecs = { |cur, nxt = nil|
    var hasOnce;
    ~jitCurrentSpec = cur; ~jitNextSpec = nxt;
    hasOnce = ~jitGuiRefreshOnce.notNil;
    if(hasOnce) { ~jitGuiRefreshOnce.() }{ (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh }) };
};

~jitGuiBind = {
    var cb;
    (~jitGUI[\bound]).if({ nil }, {
        cb = { |phase, payload|
            { if(~jitGuiRefreshOnce.notNil) { ~jitGuiRefreshOnce.() } { (~jitGUI[\view].notNil).if({ ~jitGUI[\view].refresh }) } }.defer
        };
        (~jitAddListener ? { |fn| ~jitListeners = (~jitListeners ? Array.new).add(fn) }).value(cb);
        ~jitGUI[\listener] = cb; ~jitGUI[\bound] = true;
    });
};

~jitGuiUnbind = {
    var cb;
    cb = ~jitGUI[\listener];
    (cb.notNil and: { ~jitRemoveListener.notNil }).if({ ~jitRemoveListener.(cb) });
    ~jitGUI[\listener] = nil; ~jitGUI[\bound] = false;
};

~jitGuiStartTimer = {
    (~jitGUI[\timer].notNil).if({ ~jitGUI[\timer].stop; ~jitGUI[\timer] = nil; });
    ~jitGUI[\timer] = Routine({
        var alive;
        alive = true;
        while({ alive }, {
            if(~jitGuiRefreshOnce.notNil) { { ~jitGuiRefreshOnce.() }.defer } { (~jitGUI[\view].notNil).if({ { ~jitGUI[\view].refresh }.defer }) };
            0.25.wait;
            alive = (~jitGUI[\window].notNil) and: { ~jitGUI[\window].isClosed.not };
        });
    }).play(AppClock);
};

~jitGuiStopTimer = {
    (~jitGUI[\timer].notNil).if({ ~jitGUI[\timer].stop; ~jitGUI[\timer] = nil; });
};

// --- GUI API: window with bottom bar controls (Preview / Switch) ---
~jitGuiShow = { |useListeners = true|
    var w, uv, s, colors, bar, barH, btnW, pad, makeButtons, updateLayout;

    s = ~jitGuiState; colors = ~jitGuiColors;

    // Default preview spec global (editable at runtime)
    ~jitGuiPreviewSpec = ~jitGuiPreviewSpec ? (~demoSpec_swirl ? [\guitar, \destinationStereo]);

    if(~jitGUI[\window].isNil or: { ~jitGUI[\window].isClosed }) {
        w = Window("Chain View v4", Rect(60, 60, (900 * s[\scale]).clip(500, 1600), (320 * s[\scale]).clip(240, 1400)))
        .background_(colors[\bg]);

        // Layout constants
        barH = (36 * s[\scale]).clip(26, 60);
        pad  = (8 * s[\scale]).clip(6, 16);
        btnW = (160 * s[\scale]).clip(110, 220);

        // Create views
        uv = UserView(w, w.view.bounds)
        .background_(colors[\bg])
        .clearOnRefresh_(true)
        .acceptsMouse_(false);

        bar = CompositeView(w, Rect(0, 0, 10, barH)).background_(colors[\bg]);

        ~jitGUI[\window] = w; ~jitGUI[\view] = uv;

        // Draw function unchanged
        uv.drawFunc = { ~jitGui_drawFunc.() };

        // Helper to lay out views on resize
        updateLayout = {
            var vb;
            vb = w.view.bounds;
            bar.bounds = Rect(vb.left, vb.bottom - barH, vb.width, barH);
            uv.bounds  = Rect(vb.left, vb.top, vb.width, vb.height - barH);
            uv.refresh;
        };

        // Create buttons in the bottom bar
        makeButtons = {
            var bPrev, bNow, bLater, x0, y0, h;

            x0 = pad; y0 = pad; h = (barH - (pad * 2)).max(20);

            bPrev = Button(bar, Rect(x0, y0, btnW, h))
                .states([["Preview as Next", colors[\text], Color.clear]])
                .action_({ |btn|
                    var spec;
                    spec = ~jitGuiPreviewSpec ? (~demoSpec_swirl ? [\guitar, \destinationStereo]);
                    ~jitCFPreview.(spec);
                });

            bNow = Button(bar, Rect(x0 + btnW + pad, y0, btnW, h))
                .states([["Switch Now", colors[\text], Color.clear]])
                .action_({ |btn| ~jitCFSwitchNow.() });

            bLater = Button(bar, Rect(x0 + (btnW * 2) + (pad * 2), y0, btnW, h))
                .states([["Switch in 2s", colors[\text], Color.clear]])
                .action_({ |btn| ~jitCFSwitchIn.(2.0) });
        };

        // Build controls and layout
        makeButtons.();
        updateLayout.();

        // Resize behavior
        w.view.onResize_({ updateLayout.() });

        // Keyboard actions unchanged
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

        w.onClose_({
            ~jitGuiStopTimer.(); ~jitGuiUnbind.();
            ~jitGUI = (~jitGUI.copy.putAll((window: nil, view: nil, timer: nil, listener: nil, bound: false)));
        });

        uv.refresh; w.front;

    }{
        ~jitGUI[\view].refresh; ~jitGUI[\window].front;
    };
};

)
