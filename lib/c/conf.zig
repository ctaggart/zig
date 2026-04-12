const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno_fn = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&fpathconf, "fpathconf");
        symbol(&pathconf, "pathconf");
    }
    if (builtin.target.isWasiLibC()) {
        symbol(&fpathconf, "fpathconf");
        symbol(&pathconf, "pathconf");
    }
}

// POSIX limit values
const _POSIX_LINK_MAX = 8;
const _POSIX_MAX_CANON = 255;
const _POSIX_MAX_INPUT = 255;
const NAME_MAX = 255;
const PATH_MAX = 4096;
const PIPE_BUF = 4096;
const FILESIZEBITS = 64;

// _PC_ index values (from POSIX / musl unistd.h)
const values = [21]c_short{
    _POSIX_LINK_MAX, // _PC_LINK_MAX = 0
    _POSIX_MAX_CANON, // _PC_MAX_CANON = 1
    _POSIX_MAX_INPUT, // _PC_MAX_INPUT = 2
    NAME_MAX, // _PC_NAME_MAX = 3
    PATH_MAX, // _PC_PATH_MAX = 4
    PIPE_BUF, // _PC_PIPE_BUF = 5
    1, // _PC_CHOWN_RESTRICTED = 6
    1, // _PC_NO_TRUNC = 7
    0, // _PC_VDISABLE = 8
    1, // _PC_SYNC_IO = 9
    -1, // _PC_ASYNC_IO = 10
    -1, // _PC_PRIO_IO = 11
    -1, // _PC_SOCK_MAXBUF = 12
    FILESIZEBITS, // _PC_FILESIZEBITS = 13
    4096, // _PC_REC_INCR_XFER_SIZE = 14
    4096, // _PC_REC_MAX_XFER_SIZE = 15
    4096, // _PC_REC_MIN_XFER_SIZE = 16
    4096, // _PC_REC_XFER_ALIGN = 17
    4096, // _PC_ALLOC_SIZE_MIN = 18
    -1, // _PC_SYMLINK_MAX = 19
    1, // _PC_2_SYMLINKS = 20
};

fn fpathconf(_: c_int, name: c_int) callconv(.c) c_long {
    if (name < 0 or name >= values.len) {
        if (builtin.os.tag == .linux) {
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
        }
        return -1;
    }
    return values[@intCast(name)];
}

fn pathconf(_: ?[*:0]const u8, name: c_int) callconv(.c) c_long {
    return fpathconf(-1, name);
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&get_nprocs_conf, "get_nprocs_conf");
        symbol(&get_nprocs, "get_nprocs");
        symbol(&get_phys_pages, "get_phys_pages");
        symbol(&get_avphys_pages, "get_avphys_pages");
    }
}

extern "c" fn sysconf(name: c_int) c_long;

const _SC_NPROCESSORS_CONF = 83;
const _SC_NPROCESSORS_ONLN = 84;
const _SC_PHYS_PAGES = 85;
const _SC_AVPHYS_PAGES = 86;

fn get_nprocs_conf() callconv(.c) c_int {
    return @intCast(sysconf(_SC_NPROCESSORS_CONF));
}

fn get_nprocs() callconv(.c) c_int {
    return @intCast(sysconf(_SC_NPROCESSORS_ONLN));
}

fn get_phys_pages() callconv(.c) c_long {
    return sysconf(_SC_PHYS_PAGES);
}

fn get_avphys_pages() callconv(.c) c_long {
    return sysconf(_SC_AVPHYS_PAGES);
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&confstr, "confstr");
    }
}

const _CS_POSIX_V6_ILP32_OFF32_CFLAGS = 1116;

fn confstr(name: c_int, buf: ?[*]u8, len: usize) callconv(.c) usize {
    const s: [*:0]const u8 = if (name == 0)
        "/bin:/usr/bin"
    else if ((@as(c_uint, @bitCast(name)) & ~@as(c_uint, 4)) != 1 and
        @as(c_uint, @bitCast(name -% _CS_POSIX_V6_ILP32_OFF32_CFLAGS)) > 35)
    {
        if (builtin.os.tag == .linux)
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return 0;
    } else
        "";

    // Find length of s.
    var slen: usize = 0;
    while (s[slen] != 0) : (slen += 1) {}

    // Copy with truncation.
    if (buf) |b| {
        if (len > 0) {
            const copy_len = if (slen < len - 1) slen else len - 1;
            @memcpy(b[0..copy_len], s[0..copy_len]);
            b[copy_len] = 0;
        }
    }
    return slen + 1;
    if (builtin.link_libc) {
        symbol(&sysconf, "sysconf");
    }
}

const _POSIX_VERSION: c_long = 200809;
const LONG_MAX = std.math.maxInt(c_long);

// Encoded table values
const VER: c_int = -256 | 1;
const JT_ARG_MAX: c_int = -256 | 2;
const JT_MQ_PRIO_MAX: c_int = -256 | 3;
const JT_PAGE_SIZE: c_int = -256 | 4;
const JT_SEM_VALUE_MAX: c_int = -256 | 5;
const JT_NPROCESSORS: c_int = -256 | 6;
const JT_PHYS_PAGES: c_int = -256 | 8;
const JT_AVPHYS_PAGES: c_int = -256 | 9;
const JT_ZERO: c_int = -256 | 10;
const JT_DELAYTIMER_MAX: c_int = -256 | 11;
const JT_MINSIGSTKSZ: c_int = -256 | 12;
const JT_SIGSTKSZ: c_int = -256 | 13;
const RLIM_NPROC: c_int = @bitCast(@as(c_uint, 0x80000000 | 6)); // RLIMIT_NPROC
const RLIM_NOFILE: c_int = @bitCast(@as(c_uint, 0x80000000 | 7)); // RLIMIT_NOFILE
const sz_long: c_int = @sizeOf(c_long);

// Table size: _SC values go up to ~199 on Linux
const TABLE_SIZE = 200;

const values: [TABLE_SIZE]c_int = blk: {
    var t: [TABLE_SIZE]c_int = .{0} ** TABLE_SIZE;
    t[0] = JT_ARG_MAX; // _SC_ARG_MAX
    t[1] = RLIM_NPROC; // _SC_CHILD_MAX
    t[2] = 100; // _SC_CLK_TCK
    t[3] = 32; // _SC_NGROUPS_MAX
    t[4] = RLIM_NOFILE; // _SC_OPEN_MAX
    t[5] = -1; // _SC_STREAM_MAX
    t[6] = if (@sizeOf(c_long) == 8) 6 else 6; // _SC_TZNAME_MAX (TZNAME_MAX=6)
    t[7] = 1; // _SC_JOB_CONTROL
    t[8] = 1; // _SC_SAVED_IDS
    t[9] = VER; // _SC_REALTIME_SIGNALS
    t[10] = -1; // _SC_PRIORITY_SCHEDULING
    t[11] = VER; // _SC_TIMERS
    t[12] = VER; // _SC_ASYNCHRONOUS_IO
    t[13] = -1; // _SC_PRIORITIZED_IO
    t[14] = -1; // _SC_SYNCHRONIZED_IO
    t[15] = VER; // _SC_FSYNC
    t[16] = VER; // _SC_MAPPED_FILES
    t[17] = VER; // _SC_MEMLOCK
    t[18] = VER; // _SC_MEMLOCK_RANGE
    t[19] = VER; // _SC_MEMORY_PROTECTION
    t[20] = VER; // _SC_MESSAGE_PASSING
    t[21] = VER; // _SC_SEMAPHORES
    t[22] = VER; // _SC_SHARED_MEMORY_OBJECTS
    t[23] = -1; // _SC_AIO_LISTIO_MAX
    t[24] = -1; // _SC_AIO_MAX
    t[25] = JT_ZERO; // _SC_AIO_PRIO_DELTA_MAX
    t[26] = JT_DELAYTIMER_MAX; // _SC_DELAYTIMER_MAX
    t[27] = -1; // _SC_MQ_OPEN_MAX
    t[28] = JT_MQ_PRIO_MAX; // _SC_MQ_PRIO_MAX
    t[29] = VER; // _SC_VERSION
    t[30] = JT_PAGE_SIZE; // _SC_PAGE_SIZE
    t[31] = 31; // _SC_RTSIG_MAX (64-1-31-3 on most, simplified)
    t[32] = 256; // _SC_SEM_NSEMS_MAX
    t[33] = JT_SEM_VALUE_MAX; // _SC_SEM_VALUE_MAX
    t[34] = -1; // _SC_SIGQUEUE_MAX
    t[35] = -1; // _SC_TIMER_MAX
    t[36] = 99; // _SC_BC_BASE_MAX
    t[37] = 2048; // _SC_BC_DIM_MAX
    t[38] = 99; // _SC_BC_SCALE_MAX
    t[39] = 1000; // _SC_BC_STRING_MAX
    t[40] = 2; // _SC_COLL_WEIGHTS_MAX
    t[41] = -1; // _SC_EXPR_NEST_MAX
    t[42] = -1; // _SC_LINE_MAX
    t[43] = 255; // _SC_RE_DUP_MAX
    t[44] = VER; // _SC_2_VERSION
    t[45] = VER; // _SC_2_C_BIND
    t[46] = -1; // _SC_2_C_DEV
    t[47] = -1; // _SC_2_FORT_DEV
    t[48] = -1; // _SC_2_FORT_RUN
    t[49] = -1; // _SC_2_SW_DEV
    t[50] = -1; // _SC_2_LOCALEDEF
    t[51] = 1024; // _SC_IOV_MAX
    // 52..54 unused
    t[55] = VER; // _SC_THREADS
    t[56] = VER; // _SC_THREAD_SAFE_FUNCTIONS
    t[57] = -1; // _SC_GETGR_R_SIZE_MAX
    t[58] = -1; // _SC_GETPW_R_SIZE_MAX
    t[59] = 256; // _SC_LOGIN_NAME_MAX
    t[60] = 32; // _SC_TTY_NAME_MAX
    t[61] = 4; // _SC_THREAD_DESTRUCTOR_ITERATIONS
    t[62] = 128; // _SC_THREAD_KEYS_MAX
    t[63] = 131072; // _SC_THREAD_STACK_MIN
    t[64] = -1; // _SC_THREAD_THREADS_MAX
    t[65] = VER; // _SC_THREAD_ATTR_STACKADDR
    t[66] = VER; // _SC_THREAD_ATTR_STACKSIZE
    t[67] = VER; // _SC_THREAD_PRIORITY_SCHEDULING
    t[68] = -1; // _SC_THREAD_PRIO_INHERIT
    t[69] = -1; // _SC_THREAD_PRIO_PROTECT
    t[70] = VER; // _SC_THREAD_PROCESS_SHARED
    // 71..82 unused
    t[83] = JT_NPROCESSORS; // _SC_NPROCESSORS_CONF
    t[84] = JT_NPROCESSORS; // _SC_NPROCESSORS_ONLN
    t[85] = JT_PHYS_PAGES; // _SC_PHYS_PAGES
    t[86] = JT_AVPHYS_PAGES; // _SC_AVPHYS_PAGES
    t[87] = -1; // _SC_ATEXIT_MAX
    t[88] = -1; // _SC_PASS_MAX
    t[89] = 700; // _SC_XOPEN_VERSION
    t[90] = 700; // _SC_XOPEN_XCU_VERSION
    t[91] = 1; // _SC_XOPEN_UNIX
    t[92] = -1; // _SC_XOPEN_CRYPT
    t[93] = 1; // _SC_XOPEN_ENH_I18N
    t[94] = 1; // _SC_XOPEN_SHM
    t[95] = -1; // _SC_2_CHAR_TERM
    t[96] = -1; // _SC_2_UPE
    t[97] = -1; // _SC_XOPEN_XPG2
    t[98] = -1; // _SC_XOPEN_XPG3
    t[99] = -1; // _SC_XOPEN_XPG4
    t[100] = 20; // _SC_NZERO
    t[109] = -1; // _SC_XBS5_ILP32_OFF32
    t[110] = if (sz_long == 4) 1 else -1; // _SC_XBS5_ILP32_OFFBIG
    t[111] = if (sz_long == 8) 1 else -1; // _SC_XBS5_LP64_OFF64
    t[112] = -1; // _SC_XBS5_LPBIG_OFFBIG
    t[113] = -1; // _SC_XOPEN_LEGACY
    t[114] = -1; // _SC_XOPEN_REALTIME
    t[115] = -1; // _SC_XOPEN_REALTIME_THREADS
    t[132] = VER; // _SC_ADVISORY_INFO
    t[133] = VER; // _SC_BARRIERS
    t[134] = VER; // _SC_CLOCK_SELECTION
    t[135] = VER; // _SC_CPUTIME
    t[136] = VER; // _SC_THREAD_CPUTIME
    t[137] = VER; // _SC_MONOTONIC_CLOCK
    t[138] = VER; // _SC_READER_WRITER_LOCKS
    t[139] = VER; // _SC_SPIN_LOCKS
    t[140] = 1; // _SC_REGEXP
    t[141] = 1; // _SC_SHELL
    t[142] = VER; // _SC_SPAWN
    t[143] = -1; // _SC_SPORADIC_SERVER
    t[144] = -1; // _SC_THREAD_SPORADIC_SERVER
    t[145] = VER; // _SC_TIMEOUTS
    t[146] = -1; // _SC_TYPED_MEMORY_OBJECTS
    t[147] = -1; // _SC_2_PBS
    t[148] = -1; // _SC_2_PBS_ACCOUNTING
    t[149] = -1; // _SC_2_PBS_LOCATE
    t[150] = -1; // _SC_2_PBS_MESSAGE
    t[151] = -1; // _SC_2_PBS_TRACK
    t[152] = 40; // _SC_SYMLOOP_MAX
    t[153] = JT_ZERO; // _SC_STREAMS
    t[154] = -1; // _SC_2_PBS_CHECKPOINT
    t[155] = -1; // _SC_V6_ILP32_OFF32
    t[156] = if (sz_long == 4) 1 else -1; // _SC_V6_ILP32_OFFBIG
    t[157] = if (sz_long == 8) 1 else -1; // _SC_V6_LP64_OFF64
    t[158] = -1; // _SC_V6_LPBIG_OFFBIG
    t[159] = 64; // _SC_HOST_NAME_MAX
    t[160] = -1; // _SC_TRACE
    t[161] = -1; // _SC_TRACE_EVENT_FILTER
    t[162] = -1; // _SC_TRACE_INHERIT
    t[163] = -1; // _SC_TRACE_LOG
    t[164] = VER; // _SC_IPV6
    t[165] = VER; // _SC_RAW_SOCKETS
    t[166] = -1; // _SC_V7_ILP32_OFF32
    t[167] = if (sz_long == 4) 1 else -1; // _SC_V7_ILP32_OFFBIG
    t[168] = if (sz_long == 8) 1 else -1; // _SC_V7_LP64_OFF64
    t[169] = -1; // _SC_V7_LPBIG_OFFBIG
    t[170] = -1; // _SC_SS_REPL_MAX
    t[171] = -1; // _SC_TRACE_EVENT_NAME_MAX
    t[172] = -1; // _SC_TRACE_NAME_MAX
    t[173] = -1; // _SC_TRACE_SYS_MAX
    t[174] = -1; // _SC_TRACE_USER_EVENT_MAX
    t[175] = JT_ZERO; // _SC_XOPEN_STREAMS
    t[176] = -1; // _SC_THREAD_ROBUST_PRIO_INHERIT
    t[177] = -1; // _SC_THREAD_ROBUST_PRIO_PROTECT
    t[178] = JT_MINSIGSTKSZ; // _SC_MINSIGSTKSZ
    t[179] = JT_SIGSTKSZ; // _SC_SIGSTKSZ
        symbol(&confstr, "confstr");
        symbol(&sysconf, "sysconf");
        if (builtin.link_libc) {
            symbol(&get_nprocs_conf, "get_nprocs_conf");
            symbol(&get_nprocs, "get_nprocs");
            symbol(&get_phys_pages, "get_phys_pages");
            symbol(&get_avphys_pages, "get_avphys_pages");
        }
    }
}

// --- fpathconf / pathconf ---

const pc_values = [21]c_short{ 8, 255, 255, 255, 4096, 4096, 1, 1, 0, 1, -1, -1, -1, 64, 4096, 4096, 4096, 4096, 4096, -1, 1 };

fn fpathconf(fd: c_int, name: c_int) callconv(.c) c_long {
    _ = fd;
    if (name < 0 or name >= pc_values.len) { std.c._errno().* = @intFromEnum(linux.E.INVAL); return -1; }
    return pc_values[@intCast(name)];
}

fn pathconf(path: [*:0]const u8, name: c_int) callconv(.c) c_long {
    _ = path;
    return fpathconf(-1, name);
}

// --- confstr ---

fn confstr(name: c_int, buf: ?[*]u8, len: usize) callconv(.c) usize {
    const s: [*:0]const u8 = blk: {
        if (name == 0) break :blk "/bin:/usr/bin";
        if ((name & ~@as(c_int, 4)) == 1) break :blk "";
        if (name >= 1116 and name - 1116 <= 35) break :blk "";
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return 0;
    };
    var slen: usize = 0;
    while (s[slen] != 0) slen += 1;
    if (buf) |b| {
        if (len > 0) { const c = @min(slen, len - 1); @memcpy(b[0..c], s[0..c]); b[c] = 0; }
    }
    return slen + 1;
}

// --- sysconf ---

// Value encoding: direct (>= -1), RLIM (< -32768), jump table (-256..-2)
const VER: c_short = -255; // JT(1)
const JT_ARG_MAX: c_short = -254;
const JT_MQ_PRIO_MAX: c_short = -253;
const JT_PAGE_SIZE: c_short = -252;
const JT_SEM_VALUE_MAX: c_short = -251;
const JT_NPROCS_CONF: c_short = -250;
const JT_NPROCS_ONLN: c_short = -249;
const JT_PHYS_PAGES: c_short = -248;
const JT_AVPHYS_PAGES: c_short = -247;
const JT_ZERO: c_short = -246;
const JT_DELAYTIMER_MAX: c_short = -245;
const JT_MINSIGSTKSZ: c_short = -244;
const JT_SIGSTKSZ: c_short = -243;

const RLIM_NPROC: c_short = -32768 | 6;
const RLIM_NOFILE: c_short = -32768 | 7;

const POSIX_VERSION: c_long = 200809;
const NSIG: c_short = if (builtin.cpu.arch.isMIPS()) 128 else 65;

// Lookup table: sc_values[_SC_xxx] = encoded value
const sc_values = blk: {
    var t: [251]c_short = .{0} ** 251;
    t[0] = JT_ARG_MAX; // ARG_MAX
    t[1] = RLIM_NPROC; // CHILD_MAX
    t[2] = 100; // CLK_TCK
    t[3] = 32; // NGROUPS_MAX
    t[4] = RLIM_NOFILE; // OPEN_MAX
    t[5] = -1; // STREAM_MAX
    t[6] = 6; // TZNAME_MAX
    t[7] = 1; // JOB_CONTROL
    t[8] = 1; // SAVED_IDS
    t[9] = VER; // REALTIME_SIGNALS
    t[10] = -1; // PRIORITY_SCHEDULING
    t[11] = VER; // TIMERS
    t[12] = VER; // ASYNCHRONOUS_IO
    t[13] = -1; // PRIORITIZED_IO
    t[14] = -1; // SYNCHRONIZED_IO
    t[15] = VER; // FSYNC
    t[16] = VER; // MAPPED_FILES
    t[17] = VER; // MEMLOCK
    t[18] = VER; // MEMLOCK_RANGE
    t[19] = VER; // MEMORY_PROTECTION
    t[20] = VER; // MESSAGE_PASSING
    t[21] = VER; // SEMAPHORES
    t[22] = VER; // SHARED_MEMORY_OBJECTS
    t[23] = -1; // AIO_LISTIO_MAX
    t[24] = -1; // AIO_MAX
    t[25] = JT_ZERO; // AIO_PRIO_DELTA_MAX
    t[26] = JT_DELAYTIMER_MAX;
    t[27] = -1; // MQ_OPEN_MAX
    t[28] = JT_MQ_PRIO_MAX;
    t[29] = VER; // VERSION
    t[30] = JT_PAGE_SIZE;
    t[31] = NSIG - 1 - 31 - 3; // RTSIG_MAX
    t[32] = 256; // SEM_NSEMS_MAX
    t[33] = JT_SEM_VALUE_MAX;
    t[34] = -1; // SIGQUEUE_MAX
    t[35] = -1; // TIMER_MAX
    t[36] = 99; // BC_BASE_MAX
    t[37] = 2048; // BC_DIM_MAX
    t[38] = 99; // BC_SCALE_MAX
    t[39] = 1000; // BC_STRING_MAX
    t[40] = 2; // COLL_WEIGHTS_MAX
    t[42] = -1; // EXPR_NEST_MAX
    t[43] = -1; // LINE_MAX
    t[44] = 255; // RE_DUP_MAX
    t[46] = VER; // 2_VERSION
    t[47] = VER; // 2_C_BIND
    t[48] = -1; t[49] = -1; t[50] = -1; t[51] = -1; t[52] = -1;
    t[60] = 1024; // IOV_MAX
    t[67] = VER; // THREADS
    t[68] = VER; // THREAD_SAFE_FUNCTIONS
    t[69] = -1; t[70] = -1;
    t[71] = 256; // LOGIN_NAME_MAX
    t[72] = 32; // TTY_NAME_MAX
    t[73] = 4; // THREAD_DESTRUCTOR_ITERATIONS
    t[74] = 128; // THREAD_KEYS_MAX
    t[75] = 2048; // THREAD_STACK_MIN
    t[76] = -1; // THREAD_THREADS_MAX
    t[77] = VER; // THREAD_ATTR_STACKADDR
    t[78] = VER; // THREAD_ATTR_STACKSIZE
    t[79] = VER; // THREAD_PRIORITY_SCHEDULING
    t[80] = -1; t[81] = -1;
    t[82] = VER; // THREAD_PROCESS_SHARED
    t[83] = JT_NPROCS_CONF;
    t[84] = JT_NPROCS_ONLN;
    t[85] = JT_PHYS_PAGES;
    t[86] = JT_AVPHYS_PAGES;
    t[87] = -1; t[88] = -1;
    t[89] = 700; // XOPEN_VERSION
    t[90] = 700; // XOPEN_XCU_VERSION
    t[91] = 1; // XOPEN_UNIX
    t[92] = -1; // XOPEN_CRYPT
    t[93] = 1; // XOPEN_ENH_I18N
    t[94] = 1; // XOPEN_SHM
    t[96] = -1; t[97] = -1; t[98] = -1; t[99] = -1; t[100] = -1;
    t[109] = 20; // NZERO
    t[125] = -1; // XBS5_ILP32_OFF32
    t[126] = if (@sizeOf(c_long) == 4) 1 else -1;
    t[127] = if (@sizeOf(c_long) == 8) 1 else -1;
    t[128] = -1;
    t[129] = -1; t[130] = -1; t[131] = -1;
    t[132] = VER; // ADVISORY_INFO
    t[133] = VER; // BARRIERS
    t[137] = VER; // CLOCK_SELECTION
    t[138] = VER; // CPUTIME
    t[139] = VER; // THREAD_CPUTIME
    t[149] = VER; // MONOTONIC_CLOCK
    t[153] = VER; // READER_WRITER_LOCKS
    t[154] = VER; // SPIN_LOCKS
    t[155] = 1; // REGEXP
    t[157] = 1; // SHELL
    t[159] = VER; // SPAWN
    t[160] = -1; t[161] = -1;
    t[164] = VER; // TIMEOUTS
    t[165] = -1;
    t[168] = -1; t[169] = -1; t[170] = -1; t[171] = -1; t[172] = -1;
    t[173] = 40; // SYMLOOP_MAX
    t[174] = JT_ZERO; // STREAMS
    t[175] = -1;
    t[176] = -1;
    t[177] = if (@sizeOf(c_long) == 4) 1 else -1;
    t[178] = if (@sizeOf(c_long) == 8) 1 else -1;
    t[179] = -1;
    t[180] = 255; // HOST_NAME_MAX
    t[181] = -1; t[182] = -1; t[183] = -1; t[184] = -1;
    t[235] = VER; // IPV6
    t[236] = VER; // RAW_SOCKETS
    t[237] = -1;
    t[238] = if (@sizeOf(c_long) == 4) 1 else -1;
    t[239] = if (@sizeOf(c_long) == 8) 1 else -1;
    t[240] = -1; t[241] = -1; t[242] = -1; t[243] = -1; t[244] = -1;
    t[245] = -1;
    t[246] = JT_ZERO; // XOPEN_STREAMS
    t[247] = -1; t[248] = -1;
    t[249] = JT_MINSIGSTKSZ;
    t[250] = JT_SIGSTKSZ;
    break :blk t;
};

fn sysconf(name: c_int) callconv(.c) c_long {
    if (name < 0 or name >= TABLE_SIZE) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    const v = values[@intCast(name)];
    if (v == 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    if (v >= -1) return v;

    // RLIMIT query
    if (v < -256) {
        var rl: linux.rlimit = undefined;
        _ = linux.getrlimit(@enumFromInt(v & 0x3FFF), &rl);
        if (rl.cur == std.math.maxInt(u64)) return -1;
        return if (rl.cur > LONG_MAX) LONG_MAX else @intCast(rl.cur);
    }

    // Jump table entries
    const code: u8 = @truncate(@as(c_uint, @bitCast(v)));
    return switch (code) {
        1 => _POSIX_VERSION, // VER
        2 => 2097152, // ARG_MAX
        3 => 32768, // MQ_PRIO_MAX
        4 => @intCast(std.heap.page_size_min), // PAGE_SIZE
        5 => 2147483647, // SEM_VALUE_MAX (INT_MAX)
        6, 7 => blk: { // NPROCESSORS_CONF, NPROCESSORS_ONLN
            var set: [128]u8 = .{1} ++ (.{0} ** 127);
            _ = linux.syscall3(.sched_getaffinity, 0, set.len, @intFromPtr(&set));
            var cnt: c_long = 0;
            for (&set) |*byte| {
                var b = byte.*;
                while (b != 0) : (b &= b - 1) cnt += 1;
            }
            break :blk cnt;
        },
        8, 9 => blk: { // PHYS_PAGES, AVPHYS_PAGES
            var si: linux.Sysinfo = undefined;
            _ = linux.sysinfo(&si);
            const mem_unit: u64 = if (si.mem_unit == 0) 1 else si.mem_unit;
            const mem = if (code == 8) si.totalram else si.freeram +% si.bufferram;
            const result = (mem *% mem_unit) / std.heap.page_size_min;
            break :blk if (result > LONG_MAX) LONG_MAX else @intCast(result);
        },
        10 => 0, // ZERO
        11 => 2147483647, // DELAYTIMER_MAX (INT_MAX)
        12, 13 => blk: { // MINSIGSTKSZ, SIGSTKSZ
            var val: c_long = @intCast(linux.getauxval(std.elf.AT_MINSIGSTKSZ));
            if (val < linux.MINSIGSTKSZ) val = linux.MINSIGSTKSZ;
            if (code == 13) val += linux.SIGSTKSZ - linux.MINSIGSTKSZ;
            break :blk val;
        },
        else => -1,
    };
}
    if (name < 0 or name >= sc_values.len or sc_values[@intCast(name)] == 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    const v = sc_values[@intCast(name)];
    if (v >= -1) return v;

    // RLIMIT case
    if (v < -256) {
        var rl: linux.rlimit = undefined;
        _ = linux.getrlimit(@enumFromInt(v & 16383), &rl);
        if (rl.cur == std.math.maxInt(usize)) return -1;
        return if (rl.cur > std.math.maxInt(c_long)) std.math.maxInt(c_long) else @intCast(rl.cur);
    }

    // Jump table cases
    const code: u8 = @truncate(@as(u16, @bitCast(v)));
    return switch (code) {
        @as(u8, @truncate(@as(u16, @bitCast(VER)))) => POSIX_VERSION,
        @as(u8, @truncate(@as(u16, @bitCast(JT_ARG_MAX)))) => 131072,
        @as(u8, @truncate(@as(u16, @bitCast(JT_MQ_PRIO_MAX)))) => 32768,
        @as(u8, @truncate(@as(u16, @bitCast(JT_PAGE_SIZE)))) => @intCast(linux.getauxval(std.elf.AT_PAGESZ)),
        @as(u8, @truncate(@as(u16, @bitCast(JT_SEM_VALUE_MAX)))) => 0x7fffffff,
        @as(u8, @truncate(@as(u16, @bitCast(JT_DELAYTIMER_MAX)))) => 0x7fffffff,
        @as(u8, @truncate(@as(u16, @bitCast(JT_NPROCS_CONF)))),
        @as(u8, @truncate(@as(u16, @bitCast(JT_NPROCS_ONLN)))) => blk: {
            var set: [128]u8 = .{1} ++ (.{0} ** 127);
            _ = linux.syscall3(.sched_getaffinity, 0, set.len, @intFromPtr(&set));
            var cnt: c_long = 0;
            for (set) |b| cnt += @intCast(@popCount(b));
            break :blk cnt;
        },
        @as(u8, @truncate(@as(u16, @bitCast(JT_PHYS_PAGES)))),
        @as(u8, @truncate(@as(u16, @bitCast(JT_AVPHYS_PAGES)))) => blk: {
            var si: linux.Sysinfo = undefined;
            _ = linux.sysinfo(&si);
            const unit: u64 = if (si.mem_unit == 0) 1 else si.mem_unit;
            const mem: u64 = if (code == @as(u8, @truncate(@as(u16, @bitCast(JT_PHYS_PAGES)))))
                @as(u64, si.totalram) * unit
            else
                (@as(u64, si.freeram) + @as(u64, si.bufferram)) * unit;
            const page_size = linux.getauxval(std.elf.AT_PAGESZ);
            const pages = mem / page_size;
            break :blk if (pages > std.math.maxInt(c_long)) std.math.maxInt(c_long) else @intCast(pages);
        },
        @as(u8, @truncate(@as(u16, @bitCast(JT_MINSIGSTKSZ)))),
        @as(u8, @truncate(@as(u16, @bitCast(JT_SIGSTKSZ)))) => blk: {
            var val: c_long = @intCast(linux.getauxval(std.elf.AT_MINSIGSTKSZ));
            if (val < 2048) val = 2048; // MINSIGSTKSZ
            if (code == @as(u8, @truncate(@as(u16, @bitCast(JT_SIGSTKSZ)))))
                val += 8192 - 2048; // SIGSTKSZ - MINSIGSTKSZ
            break :blk val;
        },
        @as(u8, @truncate(@as(u16, @bitCast(JT_ZERO)))) => 0,
        else => v,
    };
}

// --- conf/legacy.c ---

fn get_nprocs_conf() callconv(.c) c_int { return @intCast(sysconf(83)); }
fn get_nprocs() callconv(.c) c_int { return @intCast(sysconf(84)); }
fn get_phys_pages() callconv(.c) c_long { return sysconf(85); }
fn get_avphys_pages() callconv(.c) c_long { return sysconf(86); }
