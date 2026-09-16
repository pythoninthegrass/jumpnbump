// Linked into every Tier-A unit-test module (core/build.zig's addTestStep)
// so ports can bind their extern link-time globals when the module is
// compiled standalone, where nothing else provides them:
//
// - is_server/is_net: net-mode globals (steer.zig's position_player net
//   gate); pinned to the headless singleplayer-server values.
//
// The game-loop layer will bind the real, startup-parsed storage instead.
export var is_server: c_int = 1;
export var is_net: c_int = 0;
