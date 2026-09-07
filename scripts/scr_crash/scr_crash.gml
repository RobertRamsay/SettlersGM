/// scr_crash.gml - catch an unhandled exception, write a report, offer to send it.
///
/// WHY THERE IS NO EMAIL IN HERE
///
/// A shipped game cannot send email. To talk to an SMTP server it would have to
/// carry a username and password, and everything in the executable belongs to
/// whoever downloaded it - the account would be reading other people's mail, or
/// sending spam under Bob's name, within a week of anyone caring to look. There
/// is no version of "embed the credentials but hide them well" that survives an
/// afternoon with a hex editor.
///
/// So the game POSTs the report to CRASH_REPORT_URL and something on the far
/// side does the emailing, where the credentials live on a machine the player
/// does not have. That endpoint can be a form-relay service or three lines of
/// PHP on robertramsay.co.uk - the game does not care which, it just posts.
/// Until the macro is filled in the report is written to disk and nothing is
/// sent, which is a perfectly good state to ship in: the file is beside the
/// saves and a player can attach it to a message.
///
/// AND IT ASKS FIRST
///
/// The report carries a stack trace and the tail of the net log, and the file
/// paths in those contain the player's Windows account name. Sending that
/// without asking is the kind of thing that turns up in a forum thread, so the
/// game asks once, on the next launch, and remembers the answer. A refusal is
/// remembered too - asking again every time is just wearing them down.

#macro CRASH_LOG_PATH     "settlers_crash.txt"
#macro CRASH_INI_SECTION  "crash"

/// Where a report gets posted. EMPTY MEANS NEVER SEND - the report is still
/// written to disk, and the player is not asked anything.
///
/// The body is JSON. With CRASH_REPORT_STYLE "relay" it is
/// { subject, message, access_key }, which is what the form-relay services
/// take: Formspree wants the form's own URL here and no key, Web3Forms wants
/// https://api.web3forms.com/submit and the key from the signup mail in
/// CRASH_REPORT_KEY. With "discord" it is { content } and this is a channel
/// webhook URL - see CRASH_REPORT_STYLE.
///
/// The address the mail goes TO is configured at that service, not here, which
/// is worth the trouble on its own: it can be changed without shipping a build,
/// and it is not sitting in the executable for a scraper to find.
#macro CRASH_REPORT_URL   ""

/// Only some services want one. Left empty it is left out of the request.
/// This is a submission key, not a password - the worst somebody can do with it
/// is send mail to the address it is already pointed at.
#macro CRASH_REPORT_KEY   ""

/// What shape the far end expects. "relay" is the JSON above; "discord" is a
/// Discord channel webhook, which wants { content } and nothing else.
///
/// A WEBHOOK, NOT AN ACCOUNT. Channel settings -> Integrations -> Webhooks
/// gives a URL that can do exactly one thing: post a message into that one
/// channel. It carries no login, cannot read anything, cannot touch any other
/// channel, and if it ever gets abused it is deleted and reissued. An account
/// token in a shipped game would be the whole account - every server, every DM
/// - in the hands of anyone who opened the exe in a hex editor, and automating
/// a user account is against Discord's rules on top of that.
///
/// What it does cost: the URL is in the executable, so somebody who goes
/// looking can post into that channel. Give it a channel of its own that
/// nothing else uses, and the worst case is noise in a room built for noise.
#macro CRASH_REPORT_STYLE "relay"

/// Discord rejects a message over 2000 characters outright. The report is
/// written most-useful-first - version, exception, stack, then saves, then the
/// net log - so trimming the end loses the least important part.
///
/// 1800 rather than something nearer 2000 because the header, the code fence
/// and the trimmed-here note are all outside this count, and the version
/// string in the header is not a fixed width. Worked out exactly, 1900 leaves
/// seven characters spare, which is the kind of margin that holds until the
/// day the version number gets longer and then silently drops every report.
#macro CRASH_DISCORD_MAX  1800

/// How much of the net log to attach. Enough to see what the session was doing,
/// short enough that nobody has to scroll for the stack trace.
#macro CRASH_LOG_TAIL     40

function crash_init() {
    global.crash_request  = -1;
    global.crash_pending  = "";     /* a report waiting for an answer */
    global.crash_asking   = false;
    global.crash_notice   = "";     /* what to say on screen, if anything */

    exception_unhandled_handler(crash_handler);
}

/// Called by GameMaker when something goes wrong that nothing caught. The game
/// is about to stop, so this does the least it can: build the text, write it,
/// and get out. No network here - a socket call from inside a dying runtime is
/// how a crash report becomes a hang.
function crash_handler(_ex) {
    var _text = crash_report_text(_ex);

    var _f = file_text_open_write(CRASH_LOG_PATH);
    if (_f >= 0) {
        /* One line at a time: file_text_write_string does not break on the
           newlines already in the text, so the file would be one long line. */
        var _lines = crash_split_lines(_text);
        for (var _i = 0; _i < array_length(_lines); _i++) {
            file_text_write_string(_f, _lines[_i]);
            file_text_writeln(_f);
        }
        file_text_close(_f);
    }

    show_debug_message("crash: report written to " + CRASH_LOG_PATH);
}

/// Everything worth knowing, in the order somebody reading it wants it.
function crash_report_text(_ex) {
    var _out = "SettlersGM crash report";
    _out += "\n" + date_datetime_string(date_current_datetime());
    _out += "\nversion " + game_version();
    _out += "\n" + os_get_info_line();

    _out += "\n\n--- what went wrong ---";
    if (is_struct(_ex)) {
        _out += "\n" + string(_ex.message);
        if (variable_struct_exists(_ex, "script")) {
            _out += "\nin " + string(_ex.script)
                    + " line " + string(_ex.line);
        }
        if (variable_struct_exists(_ex, "longMessage")) {
            _out += "\n" + string(_ex.longMessage);
        }
        if (variable_struct_exists(_ex, "stacktrace")) {
            _out += "\n\n--- stack ---";
            var _st = _ex.stacktrace;
            for (var _i = 0; _i < array_length(_st); _i++) {
                _out += "\n" + string(_st[_i]);
            }
        }
    } else {
        _out += "\n" + string(_ex);
    }

    _out += "\n\n--- saves ---\n" + crash_save_listing();

    /* The net log, when there is one. A crash during a networked game is much
       easier to read with the last few turns in front of you. */
    var _tail = crash_log_tail();
    if (_tail != "") {
        _out += "\n\n--- last " + string(CRASH_LOG_TAIL) + " net log lines ---\n";
        _out += _tail;
    }

    return _out;
}

/// os_get_info returns a map on some platforms and nothing useful on others, so
/// this sticks to what is always there.
function os_get_info_line() {
    return "os " + string(os_type) + " " + string(os_version)
           + ", browser " + string(browser_width) + "x" + string(browser_height)
           + ", display " + string(display_get_width())
           + "x" + string(display_get_height());
}

/// The last CRASH_LOG_TAIL lines of the net log, or "" if there is no log.
function crash_log_tail() {
    if (!file_exists(NET_LOG_PATH)) {
        return "";
    }

    var _f = file_text_open_read(NET_LOG_PATH);
    if (_f < 0) {
        return "";
    }

    /* A ring, so the whole file never has to be held at once - a long session
       writes a lot of these. */
    var _ring = array_create(CRASH_LOG_TAIL, "");
    var _n = 0;
    while (!file_text_eof(_f)) {
        _ring[_n mod CRASH_LOG_TAIL] = file_text_read_string(_f);
        file_text_readln(_f);
        _n += 1;
    }
    file_text_close(_f);

    var _first = 0;
    var _count = _n;
    if (_n > CRASH_LOG_TAIL) {
        _first = _n mod CRASH_LOG_TAIL;
        _count = CRASH_LOG_TAIL;
    }

    var _out = "";
    for (var _i = 0; _i < _count; _i++) {
        _out += _ring[(_first + _i) mod CRASH_LOG_TAIL] + "\n";
    }
    return _out;
}

/// The save slots, by name and size.
///
/// Worth having because a crash that only happens with one particular save is
/// otherwise pure guesswork - the name is what lets Bob ask for the right file.
/// It is also the one part of this report that carries something the player
/// wrote themselves, which is another reason the game asks before sending it.
function crash_save_listing() {
    var _out = "";

    for (var _i = 0; _i < SAVEGAME_SLOTS; _i++) {
        if (!savegame_slot_exists(_i)) {
            continue;
        }

        var _size = "?";
        var _b = buffer_load(savegame_slot_path(_i));
        if (_b >= 0) {
            _size = string(buffer_get_size(_b));
            buffer_delete(_b);
        }

        _out += string(_i + 1) + ". " + savegame_slot_label(_i)
                + "  (" + _size + " bytes)\n";
    }

    if (_out == "") {
        _out = "(none)\n";
    }
    return _out;
}

/// Split on newlines. Hand-rolled to match the rest of the port, which does not
/// use string_split.
function crash_split_lines(_str) {
    var _out = [];
    var _from = 1;
    var _n = string_length(_str);

    while (_from <= _n + 1) {
        var _to = _from;
        while (_to <= _n && string_char_at(_str, _to) != "\n") {
            _to += 1;
        }
        array_push(_out, string_copy(_str, _from, _to - _from));
        _from = _to + 1;
    }

    return _out;
}

// ------------------------------------------------------- the next launch

/// Called once from obj_game Create, AFTER crash_init.
///
/// If the last run left a report, this decides what to do with it. Nothing is
/// sent without an answer, and the answer is remembered - a player who said no
/// is not asked again every time they start the game.
function crash_check_previous() {
    if (!file_exists(CRASH_LOG_PATH)) {
        return;
    }

    global.crash_pending = crash_read_report();

    if (CRASH_REPORT_URL == "") {
        /* Nowhere to send it. Say where the file is and leave it alone - a
           player who wants to help can attach it to a message. */
        global.crash_notice = "The game crashed last time. The report is in "
                              + CRASH_LOG_PATH;
        return;
    }

    ini_open(PROGRESS_PATH);
    var _answer = ini_read_string(CRASH_INI_SECTION, "send", "");
    ini_close();

    if (_answer == "no") {
        crash_discard();
        return;
    }

    if (_answer == "yes") {
        crash_send();
        return;
    }

    global.crash_asking = true;
    global.crash_notice = "The game crashed last time. Send a report to the"
                          + " developer? Y / N";
}

function crash_read_report() {
    var _f = file_text_open_read(CRASH_LOG_PATH);
    if (_f < 0) {
        return "";
    }

    var _out = "";
    while (!file_text_eof(_f)) {
        _out += file_text_read_string(_f) + "\n";
        file_text_readln(_f);
    }
    file_text_close(_f);
    return _out;
}

/// Y or N, once, on the launch after a crash.
function crash_answer(_send) {
    global.crash_asking = false;

    ini_open(PROGRESS_PATH);
    if (_send) {
        ini_write_string(CRASH_INI_SECTION, "send", "yes");
    } else {
        ini_write_string(CRASH_INI_SECTION, "send", "no");
    }
    ini_close();

    if (_send) {
        crash_send();
        return;
    }
    crash_discard();
}

function crash_send() {
    if (global.crash_pending == "" || CRASH_REPORT_URL == "") {
        return;
    }

    /* json_stringify does the escaping. Building this string by hand would
       fall over on the first save called Bob"s Game, and a stack trace is full
       of backslashes. */
    var _body = {
        subject: "SettlersGM crash - " + game_version(),
        message: global.crash_pending
    };
    if (CRASH_REPORT_KEY != "") {
        _body.access_key = CRASH_REPORT_KEY;
    }

    if (CRASH_REPORT_STYLE == "discord") {
        /* A webhook takes { content } and a hard 2000-character limit. The
           report goes inside a code fence so Discord shows the stack trace as
           written instead of turning the underscores into italics. */
        var _text = global.crash_pending;
        var _room = CRASH_DISCORD_MAX;
        if (string_length(_text) > _room) {
            _text = string_copy(_text, 1, _room)
                    + "\n... trimmed, the full report is in "
                    + CRASH_LOG_PATH;
        }

        _body = {
            content: "**SettlersGM crash - " + game_version() + "**\n"
                     + "```\n" + _text + "\n```"
        };
    }

    /* http_post_string sends text/plain, which the relays reject. */
    var _headers = ds_map_create();
    ds_map_add(_headers, "Content-Type", "application/json");
    ds_map_add(_headers, "Accept", "application/json");

    global.crash_request = http_request(CRASH_REPORT_URL, "POST", _headers,
                                        json_stringify(_body));
    ds_map_destroy(_headers);

    global.crash_notice = "Sending the crash report...";
    show_debug_message("crash: posting report");
}

/// The report has been dealt with, one way or the other. The file goes, because
/// a report that stays on disk is sent again on every launch.
function crash_discard() {
    global.crash_pending = "";
    if (file_exists(CRASH_LOG_PATH)) {
        file_delete(CRASH_LOG_PATH);
    }
}

/// From obj_game's Async HTTP event. A failure is not worth troubling the
/// player with, but the file stays put so the next launch can try again.
function crash_handle_async(_async) {
    if (global.crash_request < 0) {
        return false;
    }
    if (_async[? "id"] != global.crash_request) {
        return false;
    }

    global.crash_request = -1;

    if (_async[? "status"] == 0) {
        show_debug_message("crash: report sent");
        global.crash_notice = "Crash report sent. Thank you.";
        crash_discard();
    } else {
        show_debug_message("crash: could not send the report, keeping it");
        global.crash_notice = "";
    }

    return true;
}
