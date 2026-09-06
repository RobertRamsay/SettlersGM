/// obj_game Other 62 - Async HTTP. Every http_get reply arrives here.
///
/// THE FILE NAME IS LOAD-BEARING, exactly as for Other_68.gml: GameMaker
/// matches an event's code to its declaration in obj_game.yy by file name,
/// <category>_<number>.gml, and Async HTTP is eventType 7 (Other), eventNum 62.
/// Named anything more readable, the event is declared with no code behind it -
/// the game compiles and runs and simply never hears the answer.
///
/// The only request the game makes is the start screen's update check, and it
/// checks the id before touching anything, so adding another later is safe.
update_check_handle_async(async_load);
