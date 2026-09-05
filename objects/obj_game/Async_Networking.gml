/// obj_game Async Networking - every packet and connection event arrives here.
///
/// The handler deliberately does no game work of its own: it decodes the packet
/// and files it. Starting or switching a game from inside this event would
/// rebuild the interface's float list while the event walking that list has not
/// returned - the same reason apply_pending_game exists for the start screen.
/// The Step event picks up anything that needs doing.
net_handle_async(async_load);
