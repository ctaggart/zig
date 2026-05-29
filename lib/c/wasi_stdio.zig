//! WASI stdio symbols are implemented in stdio.zig; this module provides the
//! WASI-only import boundary used by libc.zig.
const builtin = @import("builtin");

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_stdio.zig is only for WASI");
    _ = @import("stdio.zig");
}
