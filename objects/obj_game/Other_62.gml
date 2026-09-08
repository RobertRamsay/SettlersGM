/// obj_game Other 62 - Async HTTP. Every http_get reply arrives here.
///
/// THE FILE NAME IS LOAD-BEARING, exactly as for Other_68.gml: GameMaker
/// matches an event's code to its declaration in obj_game.yy by file name,
/// <category>_<number>.gml, and Async HTTP is eventType 7 (Other), eventNum 62.
/// Named anything more readable, the event is declared with no code behind it -
/// the game compiles and runs and simply never hears the answer.
///
/// Two requests can be in flight: the start screen's update check, and a crash
/// report from a previous run. Each checks the id before touching anything, and
/// the crash one answers whether it recognised the reply, so the update check
/// is not handed somebody else's.
/* Three requests can be in flight now: the start screen's update check, a
   crash report, and a play report. Each checks the id before touching
   anything, so none is handed somebody else's reply. */
if (report_handle_async(async_load)) {
    exit;
}

if (crash_handle_async(async_load)) {
    exit;
}

update_check_handle_async(async_load);
