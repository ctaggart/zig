const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
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
// _SC_* index values (from POSIX / musl unistd.h)
const _SC_ARG_MAX = 0;
const _SC_CHILD_MAX = 1;
const _SC_CLK_TCK = 2;
const _SC_NGROUPS_MAX = 3;
const _SC_OPEN_MAX = 4;
const _SC_STREAM_MAX = 5;
const _SC_TZNAME_MAX = 6;
const _SC_JOB_CONTROL = 7;
const _SC_SAVED_IDS = 8;
const _SC_REALTIME_SIGNALS = 9;
const _SC_PRIORITY_SCHEDULING = 10;
const _SC_TIMERS = 11;
const _SC_ASYNCHRONOUS_IO = 12;
const _SC_PRIORITIZED_IO = 13;
const _SC_SYNCHRONIZED_IO = 14;
const _SC_FSYNC = 15;
const _SC_MAPPED_FILES = 16;
const _SC_MEMLOCK = 17;
const _SC_MEMLOCK_RANGE = 18;
const _SC_MEMORY_PROTECTION = 19;
const _SC_MESSAGE_PASSING = 20;
const _SC_SEMAPHORES = 21;
const _SC_SHARED_MEMORY_OBJECTS = 22;
const _SC_AIO_LISTIO_MAX = 23;
const _SC_AIO_MAX = 24;
const _SC_AIO_PRIO_DELTA_MAX = 25;
const _SC_DELAYTIMER_MAX = 26;
const _SC_MQ_OPEN_MAX = 27;
const _SC_MQ_PRIO_MAX = 28;
const _SC_VERSION = 29;
const _SC_PAGE_SIZE = 30;
const _SC_RTSIG_MAX = 31;
const _SC_SEM_NSEMS_MAX = 32;
const _SC_SEM_VALUE_MAX = 33;
const _SC_SIGQUEUE_MAX = 34;
const _SC_TIMER_MAX = 35;
const _SC_BC_BASE_MAX = 36;
const _SC_BC_DIM_MAX = 37;
const _SC_BC_SCALE_MAX = 38;
const _SC_BC_STRING_MAX = 39;
const _SC_COLL_WEIGHTS_MAX = 40;
const _SC_EXPR_NEST_MAX = 42;
const _SC_LINE_MAX = 43;
const _SC_RE_DUP_MAX = 44;
const _SC_2_VERSION = 46;
const _SC_2_C_BIND = 47;
const _SC_2_C_DEV = 48;
const _SC_2_FORT_DEV = 49;
const _SC_2_FORT_RUN = 50;
const _SC_2_SW_DEV = 51;
const _SC_2_LOCALEDEF = 52;
const _SC_IOV_MAX = 60;
const _SC_THREADS = 67;
const _SC_THREAD_SAFE_FUNCTIONS = 68;
const _SC_GETGR_R_SIZE_MAX = 69;
const _SC_GETPW_R_SIZE_MAX = 70;
const _SC_LOGIN_NAME_MAX = 71;
const _SC_TTY_NAME_MAX = 72;
const _SC_THREAD_DESTRUCTOR_ITERATIONS = 73;
const _SC_THREAD_KEYS_MAX = 74;
const _SC_THREAD_STACK_MIN = 75;
const _SC_THREAD_THREADS_MAX = 76;
const _SC_THREAD_ATTR_STACKADDR = 77;
const _SC_THREAD_ATTR_STACKSIZE = 78;
const _SC_THREAD_PRIORITY_SCHEDULING = 79;
const _SC_THREAD_PRIO_INHERIT = 80;
const _SC_THREAD_PRIO_PROTECT = 81;
const _SC_THREAD_PROCESS_SHARED = 82;
const _SC_NPROCESSORS_CONF = 83;
const _SC_NPROCESSORS_ONLN = 84;
const _SC_PHYS_PAGES = 85;
const _SC_AVPHYS_PAGES = 86;
const _SC_ATEXIT_MAX = 87;
const _SC_PASS_MAX = 88;
const _SC_XOPEN_VERSION = 89;
const _SC_XOPEN_XCU_VERSION = 90;
const _SC_XOPEN_UNIX = 91;
const _SC_XOPEN_CRYPT = 92;
const _SC_XOPEN_ENH_I18N = 93;
const _SC_XOPEN_SHM = 94;
const _SC_2_CHAR_TERM = 95;
const _SC_2_UPE = 97;
const _SC_XOPEN_XPG2 = 98;
const _SC_XOPEN_XPG3 = 99;
const _SC_XOPEN_XPG4 = 100;
const _SC_NZERO = 109;
const _SC_XBS5_ILP32_OFF32 = 125;
const _SC_XBS5_ILP32_OFFBIG = 126;
const _SC_XBS5_LP64_OFF64 = 127;
const _SC_XBS5_LPBIG_OFFBIG = 128;
const _SC_XOPEN_LEGACY = 129;
const _SC_XOPEN_REALTIME = 130;
const _SC_XOPEN_REALTIME_THREADS = 131;
const _SC_ADVISORY_INFO = 132;
const _SC_BARRIERS = 133;
const _SC_CLOCK_SELECTION = 137;
const _SC_CPUTIME = 138;
const _SC_THREAD_CPUTIME = 139;
const _SC_MONOTONIC_CLOCK = 149;
const _SC_READER_WRITER_LOCKS = 153;
const _SC_SPIN_LOCKS = 154;
const _SC_REGEXP = 155;
const _SC_SHELL = 157;
const _SC_SPAWN = 159;
const _SC_SPORADIC_SERVER = 160;
const _SC_THREAD_SPORADIC_SERVER = 161;
const _SC_TIMEOUTS = 164;
const _SC_TYPED_MEMORY_OBJECTS = 165;
const _SC_2_PBS = 168;
const _SC_2_PBS_ACCOUNTING = 169;
const _SC_2_PBS_LOCATE = 170;
const _SC_2_PBS_MESSAGE = 171;
const _SC_2_PBS_TRACK = 172;
const _SC_SYMLOOP_MAX = 173;
const _SC_STREAMS = 174;
const _SC_2_PBS_CHECKPOINT = 175;
const _SC_V6_ILP32_OFF32 = 176;
const _SC_V6_ILP32_OFFBIG = 177;
const _SC_V6_LP64_OFF64 = 178;
const _SC_V6_LPBIG_OFFBIG = 179;
const _SC_HOST_NAME_MAX = 180;
const _SC_TRACE = 181;
const _SC_TRACE_EVENT_FILTER = 182;
const _SC_TRACE_INHERIT = 183;
const _SC_TRACE_LOG = 184;
const _SC_IPV6 = 235;
const _SC_RAW_SOCKETS = 236;
const _SC_V7_ILP32_OFF32 = 237;
const _SC_V7_ILP32_OFFBIG = 238;
const _SC_V7_LP64_OFF64 = 239;
const _SC_V7_LPBIG_OFFBIG = 240;
const _SC_SS_REPL_MAX = 241;
const _SC_TRACE_EVENT_NAME_MAX = 242;
const _SC_TRACE_NAME_MAX = 243;
const _SC_TRACE_SYS_MAX = 244;
const _SC_TRACE_USER_EVENT_MAX = 245;
const _SC_XOPEN_STREAMS = 246;
const _SC_THREAD_ROBUST_PRIO_INHERIT = 247;
const _SC_THREAD_ROBUST_PRIO_PROTECT = 248;
const _SC_MINSIGSTKSZ = 249;
const _SC_SIGSTKSZ = 250;
const SC_TABLE_LEN = 251;

const _CS_POSIX_V6_ILP32_OFF32_CFLAGS = 1116;
const _POSIX_VERSION: c_long = 200809;
const LONG_MAX = std.math.maxInt(c_long);

// Direct values used in the _SC_ table (from musl limits.h / arch headers)
const TZNAME_MAX: c_short = 6;
const COLL_WEIGHTS_MAX: c_short = 2;
const RE_DUP_MAX: c_short = 255;
const IOV_MAX: c_short = 1024;
const TTY_NAME_MAX: c_short = 32;
const PTHREAD_DESTRUCTOR_ITERATIONS: c_short = 4;
const PTHREAD_KEYS_MAX: c_short = 128;
const PTHREAD_STACK_MIN: c_short = 2048;
const NZERO: c_short = 20;
const HOST_NAME_MAX: c_short = 255;
const SYMLOOP_MAX: c_short = 40;
const SEM_NSEMS_MAX: c_short = 256;
const _XOPEN_VERSION: c_short = 700;
const _NSIG: c_short = 65;
const _POSIX2_BC_BASE_MAX: c_short = 99;
const _POSIX2_BC_DIM_MAX: c_short = 2048;
const _POSIX2_BC_SCALE_MAX: c_short = 99;
const _POSIX2_BC_STRING_MAX: c_short = 1000;
const LOGIN_NAME_MAX: c_short = 256;

// Encoded sentinels stored in the c_short table.
//   v == 0:        EINVAL (unknown/disabled)
//   v == -1:       not supported
//   v >= 0:        direct value
//   v in [-256,-1] (encoded as -256|x for x in 1..255): jump table case
//   v in [-32768,-256) (encoded as -32768|RLIMIT_*):     RLIMIT lookup
const VER: c_short = @bitCast(@as(u16, 0xff00 | 1));
const JT_ARG_MAX: c_short = @bitCast(@as(u16, 0xff00 | 2));
const JT_MQ_PRIO_MAX: c_short = @bitCast(@as(u16, 0xff00 | 3));
const JT_PAGE_SIZE: c_short = @bitCast(@as(u16, 0xff00 | 4));
const JT_SEM_VALUE_MAX: c_short = @bitCast(@as(u16, 0xff00 | 5));
const JT_NPROCESSORS_CONF: c_short = @bitCast(@as(u16, 0xff00 | 6));
const JT_NPROCESSORS_ONLN: c_short = @bitCast(@as(u16, 0xff00 | 7));
const JT_PHYS_PAGES: c_short = @bitCast(@as(u16, 0xff00 | 8));
const JT_AVPHYS_PAGES: c_short = @bitCast(@as(u16, 0xff00 | 9));
const JT_ZERO: c_short = @bitCast(@as(u16, 0xff00 | 10));
const JT_DELAYTIMER_MAX: c_short = @bitCast(@as(u16, 0xff00 | 11));
const JT_MINSIGSTKSZ: c_short = @bitCast(@as(u16, 0xff00 | 12));
const JT_SIGSTKSZ: c_short = @bitCast(@as(u16, 0xff00 | 13));
// RLIMIT_* numbers (most archs; differ on MIPS family)
const RLIMIT_NPROC: u16 = 6;
const RLIMIT_NOFILE: u16 = 7;
const RLIM_NPROC: c_short = @bitCast(@as(u16, 0x8000 | RLIMIT_NPROC));
const RLIM_NOFILE: c_short = @bitCast(@as(u16, 0x8000 | RLIMIT_NOFILE));

const sz_long_long_off: c_short = if (@sizeOf(c_long) == 4) 1 else -1;
const sz_long_lp64: c_short = if (@sizeOf(c_long) == 8) 1 else -1;

// Sparse table indexed by _SC_*. Defaults to 0 (= EINVAL).
const sc_values: [SC_TABLE_LEN]c_short = blk: {
    var t = [_]c_short{0} ** SC_TABLE_LEN;
    t[_SC_ARG_MAX] = JT_ARG_MAX;
    t[_SC_CHILD_MAX] = RLIM_NPROC;
    t[_SC_CLK_TCK] = 100;
    t[_SC_NGROUPS_MAX] = 32;
    t[_SC_OPEN_MAX] = RLIM_NOFILE;
    t[_SC_STREAM_MAX] = -1;
    t[_SC_TZNAME_MAX] = TZNAME_MAX;
    t[_SC_JOB_CONTROL] = 1;
    t[_SC_SAVED_IDS] = 1;
    t[_SC_REALTIME_SIGNALS] = VER;
    t[_SC_PRIORITY_SCHEDULING] = -1;
    t[_SC_TIMERS] = VER;
    t[_SC_ASYNCHRONOUS_IO] = VER;
    t[_SC_PRIORITIZED_IO] = -1;
    t[_SC_SYNCHRONIZED_IO] = -1;
    t[_SC_FSYNC] = VER;
    t[_SC_MAPPED_FILES] = VER;
    t[_SC_MEMLOCK] = VER;
    t[_SC_MEMLOCK_RANGE] = VER;
    t[_SC_MEMORY_PROTECTION] = VER;
    t[_SC_MESSAGE_PASSING] = VER;
    t[_SC_SEMAPHORES] = VER;
    t[_SC_SHARED_MEMORY_OBJECTS] = VER;
    t[_SC_AIO_LISTIO_MAX] = -1;
    t[_SC_AIO_MAX] = -1;
    t[_SC_AIO_PRIO_DELTA_MAX] = JT_ZERO;
    t[_SC_DELAYTIMER_MAX] = JT_DELAYTIMER_MAX;
    t[_SC_MQ_OPEN_MAX] = -1;
    t[_SC_MQ_PRIO_MAX] = JT_MQ_PRIO_MAX;
    t[_SC_VERSION] = VER;
    t[_SC_PAGE_SIZE] = JT_PAGE_SIZE;
    t[_SC_RTSIG_MAX] = _NSIG - 1 - 31 - 3;
    t[_SC_SEM_NSEMS_MAX] = SEM_NSEMS_MAX;
    t[_SC_SEM_VALUE_MAX] = JT_SEM_VALUE_MAX;
    t[_SC_SIGQUEUE_MAX] = -1;
    t[_SC_TIMER_MAX] = -1;
    t[_SC_BC_BASE_MAX] = _POSIX2_BC_BASE_MAX;
    t[_SC_BC_DIM_MAX] = _POSIX2_BC_DIM_MAX;
    t[_SC_BC_SCALE_MAX] = _POSIX2_BC_SCALE_MAX;
    t[_SC_BC_STRING_MAX] = _POSIX2_BC_STRING_MAX;
    t[_SC_COLL_WEIGHTS_MAX] = COLL_WEIGHTS_MAX;
    t[_SC_EXPR_NEST_MAX] = -1;
    t[_SC_LINE_MAX] = -1;
    t[_SC_RE_DUP_MAX] = RE_DUP_MAX;
    t[_SC_2_VERSION] = VER;
    t[_SC_2_C_BIND] = VER;
    t[_SC_2_C_DEV] = -1;
    t[_SC_2_FORT_DEV] = -1;
    t[_SC_2_FORT_RUN] = -1;
    t[_SC_2_SW_DEV] = -1;
    t[_SC_2_LOCALEDEF] = -1;
    t[_SC_IOV_MAX] = IOV_MAX;
    t[_SC_THREADS] = VER;
    t[_SC_THREAD_SAFE_FUNCTIONS] = VER;
    t[_SC_GETGR_R_SIZE_MAX] = -1;
    t[_SC_GETPW_R_SIZE_MAX] = -1;
    t[_SC_LOGIN_NAME_MAX] = LOGIN_NAME_MAX;
    t[_SC_TTY_NAME_MAX] = TTY_NAME_MAX;
    t[_SC_THREAD_DESTRUCTOR_ITERATIONS] = PTHREAD_DESTRUCTOR_ITERATIONS;
    t[_SC_THREAD_KEYS_MAX] = PTHREAD_KEYS_MAX;
    t[_SC_THREAD_STACK_MIN] = PTHREAD_STACK_MIN;
    t[_SC_THREAD_THREADS_MAX] = -1;
    t[_SC_THREAD_ATTR_STACKADDR] = VER;
    t[_SC_THREAD_ATTR_STACKSIZE] = VER;
    t[_SC_THREAD_PRIORITY_SCHEDULING] = VER;
    t[_SC_THREAD_PRIO_INHERIT] = -1;
    t[_SC_THREAD_PRIO_PROTECT] = -1;
    t[_SC_THREAD_PROCESS_SHARED] = VER;
    t[_SC_NPROCESSORS_CONF] = JT_NPROCESSORS_CONF;
    t[_SC_NPROCESSORS_ONLN] = JT_NPROCESSORS_ONLN;
    t[_SC_PHYS_PAGES] = JT_PHYS_PAGES;
    t[_SC_AVPHYS_PAGES] = JT_AVPHYS_PAGES;
    t[_SC_ATEXIT_MAX] = -1;
    t[_SC_PASS_MAX] = -1;
    t[_SC_XOPEN_VERSION] = _XOPEN_VERSION;
    t[_SC_XOPEN_XCU_VERSION] = _XOPEN_VERSION;
    t[_SC_XOPEN_UNIX] = 1;
    t[_SC_XOPEN_CRYPT] = -1;
    t[_SC_XOPEN_ENH_I18N] = 1;
    t[_SC_XOPEN_SHM] = 1;
    t[_SC_2_CHAR_TERM] = -1;
    t[_SC_2_UPE] = -1;
    t[_SC_XOPEN_XPG2] = -1;
    t[_SC_XOPEN_XPG3] = -1;
    t[_SC_XOPEN_XPG4] = -1;
    t[_SC_NZERO] = NZERO;
    t[_SC_XBS5_ILP32_OFF32] = -1;
    t[_SC_XBS5_ILP32_OFFBIG] = sz_long_long_off;
    t[_SC_XBS5_LP64_OFF64] = sz_long_lp64;
    t[_SC_XBS5_LPBIG_OFFBIG] = -1;
    t[_SC_XOPEN_LEGACY] = -1;
    t[_SC_XOPEN_REALTIME] = -1;
    t[_SC_XOPEN_REALTIME_THREADS] = -1;
    t[_SC_ADVISORY_INFO] = VER;
    t[_SC_BARRIERS] = VER;
    t[_SC_CLOCK_SELECTION] = VER;
    t[_SC_CPUTIME] = VER;
    t[_SC_THREAD_CPUTIME] = VER;
    t[_SC_MONOTONIC_CLOCK] = VER;
    t[_SC_READER_WRITER_LOCKS] = VER;
    t[_SC_SPIN_LOCKS] = VER;
    t[_SC_REGEXP] = 1;
    t[_SC_SHELL] = 1;
    t[_SC_SPAWN] = VER;
    t[_SC_SPORADIC_SERVER] = -1;
    t[_SC_THREAD_SPORADIC_SERVER] = -1;
    t[_SC_TIMEOUTS] = VER;
    t[_SC_TYPED_MEMORY_OBJECTS] = -1;
    t[_SC_2_PBS] = -1;
    t[_SC_2_PBS_ACCOUNTING] = -1;
    t[_SC_2_PBS_LOCATE] = -1;
    t[_SC_2_PBS_MESSAGE] = -1;
    t[_SC_2_PBS_TRACK] = -1;
    t[_SC_SYMLOOP_MAX] = SYMLOOP_MAX;
    t[_SC_STREAMS] = JT_ZERO;
    t[_SC_2_PBS_CHECKPOINT] = -1;
    t[_SC_V6_ILP32_OFF32] = -1;
    t[_SC_V6_ILP32_OFFBIG] = sz_long_long_off;
    t[_SC_V6_LP64_OFF64] = sz_long_lp64;
    t[_SC_V6_LPBIG_OFFBIG] = -1;
    t[_SC_HOST_NAME_MAX] = HOST_NAME_MAX;
    t[_SC_TRACE] = -1;
    t[_SC_TRACE_EVENT_FILTER] = -1;
    t[_SC_TRACE_INHERIT] = -1;
    t[_SC_TRACE_LOG] = -1;
    t[_SC_IPV6] = VER;
    t[_SC_RAW_SOCKETS] = VER;
    t[_SC_V7_ILP32_OFF32] = -1;
    t[_SC_V7_ILP32_OFFBIG] = sz_long_long_off;
    t[_SC_V7_LP64_OFF64] = sz_long_lp64;
    t[_SC_V7_LPBIG_OFFBIG] = -1;
    t[_SC_SS_REPL_MAX] = -1;
    t[_SC_TRACE_EVENT_NAME_MAX] = -1;
    t[_SC_TRACE_NAME_MAX] = -1;
    t[_SC_TRACE_SYS_MAX] = -1;
    t[_SC_TRACE_USER_EVENT_MAX] = -1;
    t[_SC_XOPEN_STREAMS] = JT_ZERO;
    t[_SC_THREAD_ROBUST_PRIO_INHERIT] = -1;
    t[_SC_THREAD_ROBUST_PRIO_PROTECT] = -1;
    t[_SC_MINSIGSTKSZ] = JT_MINSIGSTKSZ;
    t[_SC_SIGSTKSZ] = JT_SIGSTKSZ;
    break :blk t;
};

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&fpathconf, "fpathconf");
        symbol(&pathconf, "pathconf");
    }
    if (builtin.target.isWasiLibC()) {}
    if (builtin.link_libc) {
        symbol(&get_nprocs_conf, "get_nprocs_conf");
        symbol(&get_nprocs, "get_nprocs");
        symbol(&get_phys_pages, "get_phys_pages");
        symbol(&get_avphys_pages, "get_avphys_pages");
        symbol(&sysconf, "sysconf");
    }
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&confstr, "confstr");
    }
}

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
}

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
}

fn confstr(name: c_int, buf: ?[*]u8, len: usize) callconv(.c) usize {
    const s: [*:0]const u8 = if (name == 0)
        "/bin:/usr/bin"
    else if ((@as(c_uint, @bitCast(name)) & ~@as(c_uint, 4)) != 1 and
        @as(c_uint, @bitCast(name -% _CS_POSIX_V6_ILP32_OFF32_CFLAGS)) > 35)
    {
        if (builtin.os.tag == .linux)
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return 0;
    } else "";

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
}

fn sysconf(name: c_int) callconv(.c) c_long {
    if (name < 0 or name >= sc_values.len) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    const v = sc_values[@intCast(name)];
    if (v == 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    if (v >= -1) return v;

    // RLIMIT query (encoded as -32768 | RLIMIT_*)
    if (v < -256) {
        var rl: linux.rlimit = undefined;
        const rlim_id: u32 = @as(u16, @bitCast(v)) & 0x3fff;
        _ = linux.getrlimit(@enumFromInt(rlim_id), &rl);
        if (rl.cur == std.math.maxInt(u64)) return -1;
        return if (rl.cur > LONG_MAX) LONG_MAX else @intCast(rl.cur);
    }

    // Jump table entries (v in [-256, -1], encoded as -256 | code)
    const code: u8 = @truncate(@as(u16, @bitCast(v)));
    return switch (code) {
        1 => _POSIX_VERSION, // VER
        2 => 131072, // ARG_MAX (matches musl include/limits.h)
        3 => 32768, // MQ_PRIO_MAX
        4 => blk: { // PAGE_SIZE — query auxv first, fall back to comptime min
            const auxval = linux.getauxval(std.elf.AT_PAGESZ);
            break :blk if (auxval != 0) @intCast(auxval) else @intCast(std.heap.page_size_min);
        },
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
