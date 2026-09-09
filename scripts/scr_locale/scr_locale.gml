// scr_locale.gml - the language the game speaks.
//
// Not in Freeserf. The original shipped as separate English and German
// builds; this is one build that asks. Every piece of text the player can
// read goes through L() at the moment it is DRAWN, so the tables that hold
// text (the notification views, the knight level names, the map generator's
// phase names) stay English and are never rebuilt - switching language is a
// matter of changing one global and the next frame comes out in the other.
//
// The English string is the key. There is no id scheme to keep in step: a
// line that has no German entry is drawn in English, which is also what
// happens if somebody types a new message somewhere and forgets this file.
// Nothing can come out blank.
//
// The font is the Amiga's own, and it decides what a translation may say:
//   - it has A-Z, 0-9, and only . - : ? % of the punctuation. No brackets,
//     no comma, no slash, no exclamation mark - those draw as a space;
//   - it DOES have Ä Ö Ü (glyphs 26, 27, 28, which Freeserf's ASCII table
//     never reached), wired up in gfx_init, so German is written with its
//     umlauts. There is no ß: write ss;
//   - it is 8 pixels a character and nothing wraps or clips, so every German
//     line here is no longer than the space its English line was given.
//     The popup content is 16 columns; the notification box holds 16 a
//     line; the start screen's rows are 29 and the net play panel's 40.
//     Where the German is cut short it is because of that, not carelessness.
//
// The choice is remembered in settlers.ini beside the mission progress and the
// last host address, under [locale] language = en | de, so the question is
// asked once. It can be changed at any time from the start screen, where the
// language name on the version row is a button, and the question comes back
// on its own if the ini goes missing.

#macro LOCALE_INI_SECTION "locale"
#macro LOCALE_INI_KEY     "language"
#macro LOCALE_EN          "en"
#macro LOCALE_DE          "de"

/* The question box, centred on the 640x400 screen. Wide enough for the longer
   of the two hint lines (29 characters) with a margin inside the frame. */
#macro LOCALE_BOX_W       280
#macro LOCALE_BOX_H       120
#macro LOCALE_BOX_X       ((SCREEN_W - LOCALE_BOX_W) div 2)
#macro LOCALE_BOX_Y       ((SCREEN_H - LOCALE_BOX_H) div 2)
#macro LOCALE_ROW_EN_Y    44
#macro LOCALE_ROW_DE_Y    62
#macro LOCALE_ROW_H       14

#macro LOCALE_COL_TEXT    make_colour_rgb(0xff, 0xff, 0xff)
#macro LOCALE_COL_LINK    make_colour_rgb(0x7c, 0xff, 0x3c)
#macro LOCALE_COL_DIM     make_colour_rgb(0xa0, 0xa0, 0xb0)

/// Everything the locale owns, laid out before anything can read it, and the
/// saved choice if there is one. Called from obj_game Create, before the
/// first draw. No saved choice means the question is asked on top of the
/// start screen (locale_prompt_draw / locale_prompt_step).
function locale_init() {
    global.locale = LOCALE_EN;
    global.locale_asking = false;
    global.locale_table = ds_map_create();
    locale_build_de();

    ini_open(PROGRESS_PATH);
    var _saved = ini_read_string(LOCALE_INI_SECTION, LOCALE_INI_KEY, "");
    ini_close();

    if (_saved == LOCALE_EN || _saved == LOCALE_DE) {
        global.locale = _saved;
    } else {
        global.locale_asking = true;
    }
    show_debug_message("locale: " + global.locale +
                       ", asking=" + string(global.locale_asking));
}

/// Switch language and remember it.
function locale_set(_lang) {
    global.locale = _lang;
    ini_open(PROGRESS_PATH);
    ini_write_string(LOCALE_INI_SECTION, LOCALE_INI_KEY, _lang);
    ini_close();
}

/// The other one. Bound to the language name on the start screen.
function locale_toggle() {
    if (global.locale == LOCALE_DE) {
        locale_set(LOCALE_EN);
    } else {
        locale_set(LOCALE_DE);
    }
}

/// What the current language calls itself, in the game font's own letters.
function locale_name() {
    if (global.locale == LOCALE_DE) {
        return "DEUTSCH";
    }
    return "ENGLISH";
}

/// The text to draw for an English string. The English itself unless the game
/// is in German AND there is a German line for it.
function L(_en) {
    if (global.locale != LOCALE_DE) {
        return _en;
    }
    var _de = ds_map_find_value(global.locale_table, _en);
    if (is_undefined(_de)) {
        return _en;
    }
    return _de;
}

/// L() with one value dropped in where the line says {0}. Used wherever a
/// number or a name sits inside a sentence, because German does not always
/// put it where English does.
function LF(_en, _arg) {
    return string_replace(L(_en), "{0}", string(_arg));
}

// ---------------------------------------------------------------------------
// The question, on top of everything, until it is answered.
// ---------------------------------------------------------------------------

/// The rectangle of one of the two answers, in screen pixels: the whole row
/// inside the frame, so it can be hit without aiming at the letters. _lang
/// picks the row. Both the drawing and the hit test read this, so what lights
/// up is what gets pressed.
function locale_row_rect(_lang) {
    var _y = LOCALE_ROW_EN_Y;
    if (_lang == LOCALE_DE) {
        _y = LOCALE_ROW_DE_Y;
    }
    return [LOCALE_BOX_X + 8, LOCALE_BOX_Y + _y - 3, LOCALE_BOX_W - 16, LOCALE_ROW_H];
}

function locale_row_hover(_lang) {
    var _r = locale_row_rect(_lang);
    return (mouse_x >= _r[0] && mouse_x < _r[0] + _r[2] &&
            mouse_y >= _r[1] && mouse_y < _r[1] + _r[3]);
}

/// One line of the game font, centred in the box.
function locale_draw_centred(_y, _str, _colour) {
    var _x = (LOCALE_BOX_W - 8 * string_length(_str)) div 2;
    gfx_draw_string(_x, _y, _str, _colour, make_colour_rgb(0, 0, 0));
}

/// Called last from obj_game Draw, so it sits over the start screen. The same
/// stone wall and plank frame as the panel underneath, with the rest of the
/// screen taken down behind it so there is no doubt what wants answering.
function locale_prompt_draw() {
    if (!global.locale_asking) {
        return;
    }

    draw_set_alpha(0.6);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, SCREEN_W, SCREEN_H, false);
    draw_set_alpha(1);
    draw_set_colour(c_white);

    gfx_set_origin(LOCALE_BOX_X, LOCALE_BOX_Y);

    /* GameInitBox.draw_bg's wall: 40x8 strips, sprites 290..294, stepped back
       a row at a time so the courses do not line up. */
    var _icon = 290;
    for (var _by = 0; _by < LOCALE_BOX_H; _by += 8) {
        for (var _bx = 0; _bx < LOCALE_BOX_W; _bx += 40) {
            gfx_draw_sprite(_bx, _by, Asset.icon, _icon);
        }
        _icon--;
        if (_icon < 290) {
            _icon = 294;
        }
    }
    draw_set_alpha(0.3);
    gfx_fill_rect(0, 0, LOCALE_BOX_W, LOCALE_BOX_H, make_colour_rgb(0, 0, 0));
    draw_set_alpha(1);
    gfx_draw_frame_box(0, 0, LOCALE_BOX_W, LOCALE_BOX_H);

    /* Both languages on every line, because nothing is known yet about which
       one is being read. */
    locale_draw_centred(18, "LANGUAGE - SPRACHE", LOCALE_COL_TEXT);

    var _en_colour = LOCALE_COL_LINK;
    if (locale_row_hover(LOCALE_EN)) {
        _en_colour = LOCALE_COL_TEXT;
    }
    var _de_colour = LOCALE_COL_LINK;
    if (locale_row_hover(LOCALE_DE)) {
        _de_colour = LOCALE_COL_TEXT;
    }
    locale_draw_centred(LOCALE_ROW_EN_Y, "ENGLISH", _en_colour);
    locale_draw_centred(LOCALE_ROW_DE_Y, "DEUTSCH", _de_colour);

    locale_draw_centred(88, "CLICK ONE - OR PRESS E OR D", LOCALE_COL_DIM);
    locale_draw_centred(100, "KLICKEN - ODER TASTE E ODER D", LOCALE_COL_DIM);

    gfx_set_origin(0, 0);
}

/// Called from obj_game Step while the question is up, INSTEAD of the rest of
/// the step: a click on an answer must not also reach the start screen
/// underneath it, and the letter keys must not become shortcuts.
function locale_prompt_step() {
    if (!global.locale_asking) {
        return;
    }

    if (keyboard_check_pressed(ord("E"))) {
        locale_answer(LOCALE_EN);
        return;
    }
    if (keyboard_check_pressed(ord("D"))) {
        locale_answer(LOCALE_DE);
        return;
    }

    if (mouse_check_button_released(mb_left)) {
        if (locale_row_hover(LOCALE_EN)) {
            locale_answer(LOCALE_EN);
        } else if (locale_row_hover(LOCALE_DE)) {
            locale_answer(LOCALE_DE);
        }
    }
}

function locale_answer(_lang) {
    locale_set(_lang);
    global.locale_asking = false;
    show_debug_message("locale: chosen " + _lang);
}

// ---------------------------------------------------------------------------
// German. Keyed by the English exactly as it appears at the draw site.
// ---------------------------------------------------------------------------

function locale_add(_en, _de) {
    ds_map_add(global.locale_table, _en, _de);
}

function locale_build_de() {
    /* ---- start screen (rows of up to 29 characters; labels sit at column
       10 and have room to column 41) */
    locale_add("Start mission", "Mission starten");
    locale_add("Mission:", "Mission:");
    locale_add("Complete", "Erledigt");
    locale_add("New game", "Neues Spiel");
    locale_add("Mapsize:", "Grösse:");
    locale_add("Load game", "Spiel laden");
    locale_add("Net play", "Netzspiel");
    locale_add("UPDATE {0} - CLICK HERE", "UPDATE {0} - HIER KLICKEN");
    locale_add("No save selected", "Kein Spielstand gewählt");
    locale_add("Slot {0} is empty", "Platz {0} ist leer");
    locale_add("Save could not be read", "Spielstand nicht lesbar");
    locale_add("Save has no usable map", "Spielstand ohne Karte");
    locale_add("Loading...", "Lade...");
    locale_add("Pick a save, then LOAD", "Spielstand wählen, dann LOAD");
    locale_add("- empty -", "- leer -");
    locale_add("saved game", "Spielstand");

    /* ---- map generation label: "GENERATING - " + phase, 29 columns */
    locale_add("GENERATING - ", "ERZEUGE - ");
    locale_add("LANDSCAPE", "LANDSCHAFT");
    locale_add("SMOOTHING", "GLÄTTEN");
    locale_add("WATER", "WASSER");
    locale_add("SEA LEVEL", "MEERESHÖHE");
    locale_add("TERRAIN", "GELÄNDE");
    locale_add("ISLANDS", "INSELN");
    locale_add("HEIGHTS", "HÖHEN");
    locale_add("SHORES", "KÜSTEN");
    locale_add("DESERTS", "WÜSTEN");
    locale_add("TREES AND STONE", "BÄUME UND STEINE");
    locale_add("MINERALS", "MINERALIEN");
    locale_add("FINISHING", "ABSCHLUSS");

    /* ---- net play panel (40 columns a line, wrapped text on fixed rows) */
    locale_add("YOU ARE HOSTING - player 2 has joined",
               "DU BIST HOST - Spieler 2 ist da");
    locale_add("YOU ARE HOSTING - waiting for player 2",
               "DU BIST HOST - warte auf Spieler 2");
    locale_add("(done)", "(fertig)");
    locale_add("[ MISSION ]", "[ MISSION ]");
    locale_add("[ CUSTOM MAP ]", "[ EIGENE KARTE ]");
    locale_add("SIZE {0}", "GRÖSSE {0}");
    locale_add("[ NEW MAP ]", "[ NEUE KARTE ]");
    locale_add("CLICK < or > to set the map size and NEW MAP to roll another, then CLICK START. It begins on both pcs at once.",
               "KLICKE < oder > für die Kartengrösse und NEUE KARTE für eine andere, dann KLICKE START. Es beginnt auf beiden PCs zugleich.");
    locale_add("[ CLICK HERE TO START ]", "[ HIER KLICKEN ZUM START ]");
    locale_add("CLICK < or > to choose the mission, then CLICK START. It begins on both pcs at once.",
               "KLICKE < oder > für die Mission, dann KLICKE START. Es beginnt auf beiden PCs zugleich.");
    locale_add("On the OTHER pc: open NET PLAY, find this pc in the list marked HOSTING, and CLICK it. Nothing more to do here until then.",
               "Am ANDEREN PC: NETZSPIEL öffnen, diesen PC in der Liste mit HOSTET suchen und KLICKEN. Hier gibt es bis dahin nichts zu tun.");
    locale_add("JOINED - you are player 2", "BEIGETRETEN - du bist Spieler 2");
    locale_add("Host is {0}. It picks the mission and CLICKS START. Nothing to click on this pc - just wait, the game opens by itself.",
               "Host ist {0}. Er wählt die Mission und KLICKT START. Hier nichts klicken - einfach warten, das Spiel öffnet sich von selbst.");
    locale_add("[ CLICK HERE TO HOST A GAME ]", "[ HIER KLICKEN UM ZU HOSTEN ]");
    locale_add("or CLICK a pc below that is HOSTING:", "oder KLICKE unten einen PC mit HOSTET:");
    locale_add("Nobody yet. Open NET PLAY on the other pc too and it appears here.",
               "Noch niemand. Öffne NETZSPIEL auch am anderen PC, dann erscheint er hier.");
    locale_add("This pc can't listen for others (second copy running?). CLICK ADD below and type the other pc's IP.",
               "Dieser PC hört nichts (zweite Kopie offen?). KLICKE unten ADD und tippe die IP des anderen PCs.");
    locale_add("Not showing up? CLICK ADD below and type the other pc's IP.",
               "Nicht zu sehen? KLICKE unten ADD und tippe die IP des anderen PCs.");
    locale_add("  online, not hosting", "  online, hostet nicht");
    locale_add("[CLICK to JOIN] ", "[KLICK - JOIN] ");
    locale_add("  HOSTING", "  HOSTET");
    locale_add("  hosting, full", "  hostet, voll");
    locale_add("? = not heard from yet. CLICK it anyway.", "? = noch nichts gehört. Trotzdem KLICKEN.");
    locale_add("TYPE the other pc's IP, then press ENTER:", "IP des anderen PCs TIPPEN, dann ENTER:");
    locale_add("(ESC cancels)", "(ESC bricht ab)");
    locale_add("[ CLICK to ADD the other pc's IP ]", "[ KLICK - IP des anderen PCs eingeben ]");
    locale_add("{0} already has a player 2", "{0} hat schon einen Spieler 2");
    locale_add("{0} is not hosting - on that pc, CLICK HOST first",
               "{0} hostet nicht - dort erst HOST KLICKEN");
    locale_add("HOSTING - on the other pc, CLICK this pc's name",
               "HOSTE - am anderen PC diesen PC ANKLICKEN");
    locale_add("player 2 left - still hosting, waiting for another",
               "Spieler 2 ging - hoste weiter, warte auf neuen");
    locale_add("already joined - press EXIT first", "schon beigetreten - erst EXIT drücken");
    locale_add("in game as player {0}", "im Spiel als Spieler {0}");
    locale_add("left net play", "Netzspiel verlassen");
    locale_add("you left the game", "du hast das Spiel verlassen");
    locale_add("  [waiting for the other player]", "  [warte auf den anderen Spieler]");
    locale_add("  BACK TO THE MENU IN {0} - ESC TO LEAVE NOW",
               "  ZURÜCK ZUM MENÜ IN {0} - ESC VERLÄSST SOFORT");

    /* ---- popups (16 columns; the column each line starts at is fixed by
       the draw site, so a line at column 4 has twelve to spend) */
    locale_add("   Do you want", "  Willst du das");
    locale_add("     to quit", "     Spiel");
    locale_add("   this game?", "   beenden?");
    locale_add("  Yes       No", "  Ja        Nein");
    locale_add("Yes", "Ja");
    locale_add("No", "Nein");
    locale_add("Send geologist", "Geologe zu");
    locale_add("to this flag?", "dieser Flagge?");
    locale_add("The game has not", "Das Spiel wurde");
    locale_add("   been saved", "  lange nicht");
    locale_add("   recently.", "  gespeichert.");
    locale_add("    Are you", "    Bist du");
    locale_add("     sure?", "    sicher?");
    locale_add("Music", "Musik");
    locale_add("Sound", "Sound");
    locale_add("effects", "effekte");
    locale_add("Volume", "Lautst.");
    locale_add("Fullscreen", "Vollbild");
    locale_add("video", "Anzeige");
    locale_add("Messages", "Meldungen");
    locale_add("All", "Alle");
    locale_add("Most", "Viele");
    locale_add("Few", "Wenig");
    locale_add("None", "Keine");
    locale_add("Invert", "Umkehren");
    locale_add("MINING", "MINEN");
    locale_add("OUTPUT:", "AUSBEUTE:");
    locale_add("Ordered", "Geplantes");
    locale_add("Building", "Gebäude");
    locale_add("Defenders:", "Verteidiger:");
    locale_add("Transport Info:", "Transportinfo:");
    locale_add("Index:", "Index:");
    locale_add("Stock of", "Lager dieses");
    locale_add("this building:", "Gebäudes:");
    locale_add("    Demolish:", "    Abreissen:");
    locale_add("   Click here", "  Hier klicken");
    locale_add("   if you are", "  wenn du dir");
    locale_add("      sure", "   sicher bist");
    locale_add("Save  Game", "Speichern");
    locale_add("Enter filename", "Name eingeben");
    locale_add("Saved to slot {0}", "Platz {0} belegt");
    locale_add("Save failed", "Fehlgeschlagen");
    locale_add("GROUND-ANALYSIS:", "BODENANALYSE:");
    locale_add("Not Present", "Nichts");
    locale_add("Minimum", "Minimal");
    locale_add("Very Few", "Sehr wenig");
    locale_add("Below Average", "Eher wenig");
    locale_add("Average", "Mittel");
    locale_add("Above Average", "Eher viel");
    locale_add("Much", "Viel");
    locale_add("Very Much", "Sehr viel");
    locale_add("Perfect", "Perfekt");
    locale_add("Weak", "Schwach");
    locale_add("Medium", "Mittel");
    locale_add("Good", "Gut");
    locale_add("Full", "Voll");

    /* ---- the end of the game (the titles are placed by column and stay
       where the English sits; see popup_draw_game_end_box) */
    locale_add("MISSION", "MISSION");
    locale_add("COMPLETE", "ERFÜLLT");
    locale_add("COMPLETE+", "ERFÜLLT+");
    locale_add("VICTORY", "SIEG");
    locale_add("SUPREME", "TOTALER");
    locale_add("FAILED", "VERLOREN");
    locale_add("DEFEATED", "BESIEGT");
    locale_add("IN PROGRESS", "IM GANGE");
    locale_add("Play on?", "Weiter?");
    locale_add("The end", "Das Ende");

    /* ---- notifications (16 characters a line, up to seven lines) */
    locale_add("Your settlement\nis under attack",
               "Deine Siedlung\nwird angegriffen");
    locale_add("Your knights\njust lost the\nfight",
               "Deine Ritter\nhaben den Kampf\nverloren");
    locale_add("You gained\na victory here",
               "Du hast hier\ngesiegt");
    locale_add("This mine hauls\nno more raw\nmaterials",
               "Diese Mine\nfördert keine\nRohstoffe mehr");
    locale_add("You wanted me\nto call you to\nthis location",
               "Du wolltest\nan diesen Ort\ngerufen werden");
    locale_add("A knight has\noccupied this\nnew building",
               "Ein Ritter hat\ndieses neue\nGebäude bezogen");
    locale_add("A new stock\nhas been built",
               "Ein neues Lager\nwurde gebaut");
    locale_add("Because of this\nenemy building\nyou lost some\nland",
               "Durch dieses\nFeindgebäude\nhast du Land\nverloren");
    locale_add("Because of this\nenemy building\nyou lost some\nland and\nsome buildings",
               "Durch dieses\nFeindgebäude\nhast du Land\nund Gebäude\nverloren");
    locale_add("Emergency\nprogram\nactivated",
               "Notprogramm\naktiviert");
    locale_add("Emergency\nprogram\nneutralized",
               "Notprogramm\nbeendet");
    locale_add("A geologist\nhas found gold",
               "Ein Geologe hat\nGold gefunden");
    locale_add("A geologist\nhas found iron",
               "Ein Geologe hat\nEisen gefunden");
    locale_add("A geologist\nhas found coal",
               "Ein Geologe hat\nKohle gefunden");
    locale_add("A geologist\nhas found stone",
               "Ein Geologe hat\nStein gefunden");
    locale_add("You wanted me\nto call you\nto this menu",
               "Du wolltest zu\ndiesem Menü\ngerufen werden");
    locale_add("30 min. passed\nsince the last\nsaving",
               "30 Min. seit\ndem letzten\nSpeichern");
    locale_add("One hour passed\nsince the last\nsaving",
               "Eine Stunde\nseit dem letzten\nSpeichern");
    locale_add("You wanted me\nto call you\nto this stock",
               "Du wolltest zu\ndiesem Lager\ngerufen werden");
    locale_add("The enemy castle\nhas fallen.\nThe land is yours",
               "Das Feindschloss\nist gefallen.\nDas Land ist dein");
    locale_add("Your castle\nhas fallen.\nYou have lost",
               "Dein Schloss\nist gefallen.\nDu hast verloren");
    locale_add("Nothing of the\nenemy remains.\nSupreme victory",
               "Vom Feind ist\nnichts mehr da.\nTotaler Sieg");
}
