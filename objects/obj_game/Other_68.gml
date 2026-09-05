/// obj_game Other 68 - Async Networking. Every packet and connection event
/// arrives here.
///
/// THE FILE NAME IS LOAD-BEARING. GameMaker matches an event's code to its
/// declaration in obj_game.yy by file name, <category>_<number>.gml, and Async
/// Networking is eventType 7 (Other), eventNum 68 - so this must be Other_68.gml
/// and nothing else. Named anything more readable, the event is declared with no
/// code behind it: the game compiles, runs, connects, and then silently ignores
/// every packet forever.
///
/// The handler deliberately does no game work of its own: it decodes the packet
/// and files it. Starting or switching a game from inside this event would
/// rebuild the interface's float list while the event walking that list has not
/// returned - the same reason apply_pending_game exists for the start screen.
/// The Step event picks up anything that needs doing.
net_handle_async(async_load);
