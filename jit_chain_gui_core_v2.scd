// jit_chain_gui_v2.scd
// Production compact chain GUI for v2
// - Auto-follows ~jitCurrentSpec and ~jitNextSpec
// - Subscribes to ~jitListeners if present; otherwise falls back to a timer refresh
// - Robust spec parsing (Array/Event forms), no font measurement calls
// - Keys: 'o' orientation, '+/-' scale, 'n' toggle next row
// - Style: tilde vars, no caret (^), vars declared first in drawFunc
(
~jitGuiColors = ~jitGuiColors ? (
	unchanged: Color(0.70, 0.70, 0.70),
	added:     Color(0.35, 0.55, 1.00),
	removed:   Color(0.95, 0.30, 0.30),
	moved:     Color(1.00, 0.55, 0.20),
	text:      Color.white,
	bg:        Color(0.10, 0.10, 0.10)
);

~jitGuiConfig = ~jitGuiConfig ? (kPerChar: 12, padW: 28, radius: 8, connectorFrac: 0.7);
~jitGuiState  = ~jitGuiState  ? (orient: \horizontal, scale: 1.6, showNext: true);
~jitGUI       = ~jitGUI       ? (window: nil, view: nil, timer: nil, listener: nil, bound: false);

// ---------- Spec parsing helpers ----------
~jitGui_norm = { |entry|
	var sym, args, rest, ev;
	sym = nil; args = [];
	if(entry.notNil and: { entry.isKindOf(Event) }) {
		ev = entry; sym = ev[\fx]; sym = sym ? ev[\sym];
		ev.keysValuesDo { |k, v| if(k != \fx and: { k != \sym }) { args = args.addAll([k, v]) } };
	}{
		if(entry.isArray) {
			sym = entry[0];
			rest = (entry.size > 1).if({ entry.copyRange(1, entry.size - 1) }, { [] });
			if(rest.size == 1 and: { rest[0].isKindOf(Event) }) {
				args = List.new; rest[0].keysValuesDo { |k, v| args.addAll([k, v]) }; args = args.asArray;
			}{
				args = rest.flat;
			};
		}{
			if(entry.respondsTo(\asSymbol)) { sym = entry.asSymbol; args = [] };
		};
	};
	[sym, args]
};

~jitGui_idAndDict = { |argsArray|
	var id, dict;
	id = nil; dict = IdentityDictionary.new;
	argsArray.clump(2).do { |kv|
		if(kv.size >= 2) {
			if(kv[0] == \id) { id = kv[1] } { dict[kv[0]] = kv[1] };
		}{
			("[jit GUI] Odd arg list; dropping trailing key: " ++ kv[0].asString).warn;
		}
	};
	[id, dict]
};

~jitGui_stagesFromSpec = { |spec|
	var mid, stages;
	mid = [];
	(spec.isArray and: { spec.size > 2 }).if({ mid = spec.copyRange(1, spec.size - 2) });
	stages = mid.collect { |entry|
		var sym, rawArgs, id, dict, label;
		# sym, rawArgs = ~jitGui_norm.(entry);
		# id, dict = ~jitGui_idAndDict.(rawArgs);
		label = id.notNil.if({ id.asString }, { (sym.notNil).if({ sym.asString }, { "<nil>" }) });
		(sym: sym, id: id, label: label)
	};
	stages
};

~jitGui_diffById = { |curStages, nextStages|
	var curIds, nxtIds, unchanged, moved, added, removed;
	curIds = curStages.collect { |st| st[\id] }.reject(_.isNil);
	nxtIds = nextStages.collect { |st| st[\id] }.reject(_.isNil);
	unchanged = nxtIds.select { |id| curIds.includes(id) and: { curIds.indexOf(id) == nxtIds.indexOf(id) } };
	moved     = nxtIds.select { |id| curIds.includes(id) and: { curIds.indexOf(id) != nxtIds.indexOf(id) } };
	added     = nxtIds.select { |id| curIds.includes(id).not };
	removed   = curIds.select { |id| nxtIds.includes(id).not };
	(unchanged: unchanged, moved: moved, added: added, removed: removed)
};

// ---------- Draw ----------
~jitGui_drawFunc = {
	var b, state, colors, cfg, font2;
	var cur, nxt, stagesCur, stagesNxt, diff;
	var pad2, nodeH2, nodeMinW2, gap2, fg2, radius, scale;
	var colorFor, drawLine, n, i, nodeW, text, c, y, x;
	var kPerChar, padW, connectorFrac, connLen;

	b      = ~jitGUI[\view].bounds;
	state  = ~jitGuiState; colors = ~jitGuiColors; cfg = ~jitGuiConfig;
	scale  = state[\scale];
	cur    = ~jitCurrentSpec;
	nxt    = (state[\showNext]).if({ ~jitNextSpec }, { nil });
	stagesCur = ~jitGui_stagesFromSpec.(cur);
	stagesNxt = (nxt.notNil).if({ ~jitGui_stagesFromSpec.(nxt) }, { [] });
	diff   = (nxt.notNil).if({ ~jitGui_diffById.(stagesCur, stagesNxt) }, { (unchanged: [], moved: [], added: [], removed: []) });

	pad2   = (10 * scale);
	nodeH2 = (44 * scale);
	nodeMinW2 = (120 * scale);
	gap2   = (18 * scale);
	fg2    = colors[\text];
	radius = (cfg[\radius] * scale);
	font2  = Font("Helvetica", (24 * scale).round(1).max(1));

	kPerChar = cfg[\kPerChar] * scale;
	padW     = cfg[\padW] * scale;
	connectorFrac = cfg[\connectorFrac].clip(0.0, 1.0);

	Pen.fillColor = colors[\bg]; Pen.addRect(b); Pen.fill;
	Pen.font = font2; Pen.strokeColor = Color.gray(0.5);

	colorFor = { |stage, isNextRow|
		var id, cOut;
		id = stage[\id]; cOut = colors[\unchanged];
		if(nxt.notNil and: { id.notNil }) {
			if(diff[\added].includes(id) and: { isNextRow }) { cOut = colors[\added] }{
				if(diff[\removed].includes(id) and: { isNextRow.not }) { cOut = colors[\removed] }{
					if(diff[\moved].includes(id)) { cOut = colors[\moved] }
				}
			}
		};
		cOut
	};

	drawLine = { |stages, rowIndex = 0, isNextRow = false|
		n = stages.size;
		if(state[\orient] == \horizontal) {
			y = pad2 + (rowIndex * (nodeH2 + gap2));
			x = b.width - pad2;
			i = n - 1;
			while({ i >= 0 }, {
				text  = stages[i][\label].asString;
				nodeW = (text.size * kPerChar + padW).clip(nodeMinW2, 600 * scale);
				x = x - nodeW - gap2;

				c = colorFor.(stages[i], isNextRow);
				Pen.fillColor = c;
				Pen.addRoundedRect(Rect(x, y, nodeW, nodeH2), radius, radius);
				Pen.fill;

				Pen.color = fg2;
				Pen.stringAtPoint(text, Point(x + (10 * scale), y + (10 * scale)));

				if(i > 0) {
					Pen.strokeColor = Color.gray(0.6);
					Pen.width = 2 * scale;

					// Longer connector with small chevron
					connLen = gap2 * connectorFrac;   // e.g. 1.0
					Pen.strokeColor = Color.gray(0.7);
					Pen.width = 2 * scale;
					// main line
					Pen.moveTo(Point(x - (connLen * 0.05), y + (nodeH2 * 0.5)));
					Pen.lineTo(Point(x - (connLen * 0.95), y + (nodeH2 * 0.5)));
					Pen.stroke;
					// tiny chevron
					Pen.moveTo(Point(x - (connLen * 0.95), y + (nodeH2 * 0.5)));
					Pen.lineTo(Point(x - (connLen * 0.85), y + (nodeH2 * 0.5) - (4 * scale)));
					Pen.moveTo(Point(x - (connLen * 0.95), y + (nodeH2 * 0.5)));
					Pen.lineTo(Point(x - (connLen * 0.85), y + (nodeH2 * 0.5) + (4 * scale)));
					Pen.stroke;
/*                    connLen = gap2 * connectorFrac;
                    Pen.moveTo(Point(x - (connLen * 0.2), y + (nodeH2 * 0.5)));
                    Pen.lineTo(Point(x - (connLen * 0.8), y + (nodeH2 * 0.5)));
                    Pen.stroke;*/
				};
				i = i - 1;
			});
		}{
			x = pad2 + (rowIndex * ((nodeMinW2 + gap2) * 0.6 + nodeMinW2));
			y = pad2; i = 0;
			while({ i < n }, {
				text  = stages[i][\label].asString;
				nodeW = (text.size * kPerChar + padW).clip(nodeMinW2, 600 * scale);

				c = colorFor.(stages[i], isNextRow);
				Pen.fillColor = c;
				Pen.addRoundedRect(Rect(x, y, nodeW, nodeH2), radius, radius);
				Pen.fill;

				Pen.color = fg2;
				Pen.stringAtPoint(text, Point(x + (10 * scale), y + (10 * scale)));

				if(i < (n - 1)) {
					Pen.strokeColor = Color.gray(0.6);
					Pen.width = 2 * scale;
					connLen = gap2 * connectorFrac;
					Pen.moveTo(Point(x + (nodeW * 0.5), y + nodeH2 + (connLen * 0.2)));
					Pen.lineTo(Point(x + (nodeW * 0.5), y + nodeH2 + (connLen * 0.8)));
					Pen.stroke;
				};
				y = y + nodeH2 + gap2; i = i + 1;
			});
		};
	};

	if(stagesCur.size == 0 and: { stagesNxt.size == 0 }) {
		Pen.color = Color.gray(0.6);
		Pen.font  = Font("Helvetica", (14 * scale).round(1).max(1));
		Pen.stringAtPoint("No stages (spec empty)", b.leftTop + (12 @ 16));
	}{
		drawLine.(stagesCur, 0, false);
		(nxt.notNil).if({ drawLine.(stagesNxt, 1, true) });
	};
};

// ---------- Public API ----------
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
		w = Window("Chain View", Rect(60, 60, (900 * s[\scale]).clip(500, 1600), (300 * s[\scale]).clip(200, 1400)))
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
