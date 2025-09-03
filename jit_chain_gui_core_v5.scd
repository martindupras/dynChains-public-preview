
// jit_chain_gui_core_v5.scd
// GUI layout and window creation for chain system

~makeMainWindow = {
    var window, layout;
    window = Window("Chain GUI", Rect(100, 100, 400, 300));
    layout = VLayout(
        StaticText().string_("Chain GUI Initialized"),
        Button().states_([ ["Play", Color.black, Color.green], ["Stop", Color.white, Color.red] ])
            .action_({ |btn|
                (btn.value == 0).if({ ~jitPlay.() }, { ~jitFree.() });
            })
    );
    window.layout_(layout);
    window.front;
    ~jitMainWindow = window;
};

~initGUI = {
    ~makeMainWindow.();
};
