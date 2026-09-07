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
/// THIS URL IS PUBLIC. It is in the executable, and it is in this file, and
/// this file is in a public repository - which is the shorter path of the two,
/// because bots scrape GitHub for exactly this string. GitHub's own secret
/// scanning knows the Discord webhook format and may revoke it on push, which
/// would be it doing the right thing.
///
/// That is survivable, and it is why a webhook is the right tool: the worst
/// anybody can do with it is post into one channel. If that channel starts
/// filling with rubbish, delete the webhook in Discord, make a new one, and
/// change this line. Nothing else is exposed. Do keep it a channel of its own
/// that nothing important lives in.
#macro CRASH_REPORT_URL   "https://discord.com/api/webhooks/1546636690276491414/C3YZs8H_pSG-4Ea5cksoWObdaWkt_YsJBhGRLiyJykgdbKdtr1A72p7mrsY9OeKd1WpW"

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
#macro CRASH_REPORT_STYLE "discord"

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

    /* Frames left on a notice that has served its purpose. A question stays up
       until it is answered; an answer gets a few seconds and then gets out of
       the way. Without this the line sat there for the rest of the session. */
    global.crash_notice_frames = 0;

    /* Where the two answers were drawn last frame, so they can be clicked.
       Filled in by the Draw event, because only the drawing knows how wide the
       words came out. */
    global.crash_yes_x1 = 0;
    global.crash_yes_x2 = 0;
    global.crash_no_x1  = 0;
    global.crash_no_x2  = 0;
    global.crash_hit_y1 = 0;
    global.crash_hit_y2 = 0;

    /* True while the handler is running. Building the report reads files,
       loads every save into a buffer and walks the net log - any of which can
       throw, and a throw from inside the handler re-enters it. That recursion
       does not stop, and a stack overflow reports as an access violation, which
       looks nothing like the bug that started it. */
    global.crash_handling = false;

    exception_unhandled_handler(crash_handler);
}

/// Called by GameMaker when something goes wrong that nothing caught. The game
/// is about to stop, so this does the least it can: build the text, write it,
/// and get out. No network here - a socket call from inside a dying runtime is
/// how a crash report becomes a hang.
function crash_handler(_ex) {
    if (global.crash_handling) {
        /* Something in here threw. Say so and stop, rather than going round
           again on the way to a stack overflow. */
        show_debug_message("crash: the crash handler itself failed");
        return;
    }
    global.crash_handling = true;

    /* The exception message on its own, first and unconditionally. Everything
       below can fail; this cannot, and it is the one line that matters. */
    var _headline = "crash: ";
    if (is_struct(_ex)) {
        _headline += string(_ex.message);
    } else {
        _headline += string(_ex);
    }
    show_debug_message(_headline);

    var _text = _headline;
    try {
        _text = crash_report_text(_ex);
    } catch (_inner) {
        /* A report that could not be built is still worth what was gathered
           before it broke, plus why it broke. */
        _text = _headline + "\n\n(the full report could not be built: "
                + string(_inner.message) + ")";
        show_debug_message("crash: could not build the full report - "
                           + string(_inner.message));
    }

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

    /* And into the output log, in full.
       Writing the file and then logging only that a file was written is a
       useless pair when the game is running from the IDE: the output window is
       right there, the developer is watching it, and it says nothing about what
       actually happened. The file is for the player's machine; this is for
       Bob's. */
    show_debug_message("=== SettlersGM crash ===");
    var _echo = crash_split_lines(_text);
    for (var _e = 0; _e < array_length(_echo); _e++) {
        show_debug_message(_echo[_e]);
    }
    show_debug_message("=== report also written to " + CRASH_LOG_PATH + " ===");

    global.crash_handling = false;
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
        /* Answered yes once before, so it goes without asking again. Said out
           loud, because a report leaving the machine unprompted should be
           visible somewhere. */
        show_debug_message("crash: a previous run said yes - sending without asking");
        crash_send();
        return;
    }

    global.crash_asking = true;
    /* Not crash_say: a question waits for an answer rather than timing out. */
    global.crash_notice_frames = 0;
    global.crash_notice = "The game crashed last time. Send a report?";
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
/// Say something and give it a life span. Every path out of the question goes
/// through here, because a question that is answered and does not change is
/// indistinguishable from a key that did nothing - which is exactly what it
/// looked like.
function crash_say(_text) {
    global.crash_notice = _text;
    global.crash_notice_frames = 5 * 60;   /* about five seconds at 60fps */
}

/// Called once a frame from obj_game's Step.
function crash_notice_step() {
    if (global.crash_notice_frames <= 0) {
        return;
    }
    global.crash_notice_frames -= 1;
    if (global.crash_notice_frames <= 0) {
        global.crash_notice = "";
    }
}

function crash_answer(_send) {
    if (!global.crash_asking) {
        return;
    }
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
    crash_say("Report discarded. It will not be sent.");
}

function crash_send() {
    /* Both of these are silent dead ends if they just return: the question is
       gone, the answer changed nothing on screen, and pressing the key again
       does nothing because crash_asking is already false. */
    if (CRASH_REPORT_URL == "") {
        crash_say("Nowhere to send it. The report is in " + CRASH_LOG_PATH);
        return;
    }
    if (global.crash_pending == "") {
        crash_say("The report could not be read from " + CRASH_LOG_PATH);
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

    /* http_post_string sends text/plain, which the relays reject.

       The User-Agent is not decoration: Discord's API refuses a request that
       does not carry one, and refuses it with a 400 that looks from this side
       exactly like the send silently not working. GameMaker does not set one
       of its own. */
    var _headers = ds_map_create();
    ds_map_add(_headers, "Content-Type", "application/json");
    ds_map_add(_headers, "Accept", "application/json");
    ds_map_add(_headers, "User-Agent",
               "SettlersGM/" + string(game_version()) + " (crash reporter)");

    global.crash_request = http_request(CRASH_REPORT_URL, "POST", _headers,
                                        json_stringify(_body));
    ds_map_destroy(_headers);

    crash_say("Sending the crash report...");
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

    /* Everything the reply says, into the log. "Could not send" on its own is
       the same non-answer as "report written" was: the HTTP code is what
       separates a blocked network from a request Discord rejected, and those
       want completely different fixes. Discord answers 204 with an empty body
       when it works. */
    var _status = _async[? "status"];
    var _http   = _async[? "http_status"];
    show_debug_message("crash: send finished - status " + string(_status)
                       + ", http " + string(_http)
                       + ", reply " + string(_async[? "result"]));

    /* status 0 means the request completed, which is not the same as the far
       end having liked it. Anything outside the 2xx range is a refusal. */
    if (_status == 0 && _http >= 200 && _http < 300) {
        show_debug_message("crash: report sent");
        crash_say("Crash report sent. Thank you.");
        crash_discard();
    } else if (_status == 0) {
        crash_say("The report was refused (HTTP " + string(_http)
                  + "). Kept for next time.");
    } else {
        crash_say("The report could not be sent. It has been kept for next"
                  + " time.");
    }

    return true;
}
