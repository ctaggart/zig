const builtin = @import("builtin");
const std = @import("std");
const c = @import("../c.zig");

const symbol = c.symbol;
const errno = c.errno;
const have_fchdir = false;

pub const FTS_COMFOLLOW: c_int = 0x001;
pub const FTS_LOGICAL: c_int = 0x002;
pub const FTS_NOCHDIR: c_int = 0x004;
pub const FTS_NOSTAT: c_int = 0x008;
pub const FTS_PHYSICAL: c_int = 0x010;
pub const FTS_SEEDOT: c_int = 0x020;
pub const FTS_XDEV: c_int = 0x040;
pub const FTS_WHITEOUT: c_int = 0x080;
pub const FTS_OPTIONMASK: c_int = 0x0ff;

pub const FTS_NAMEONLY: c_int = 0x100;
pub const FTS_STOP: c_int = 0x200;

pub const FTS_ROOTPARENTLEVEL: c_int = -1;
pub const FTS_ROOTLEVEL: c_int = 0;

pub const FTS_D: c_int = 1;
pub const FTS_DC: c_int = 2;
pub const FTS_DEFAULT: c_int = 3;
pub const FTS_DNR: c_int = 4;
pub const FTS_DOT: c_int = 5;
pub const FTS_DP: c_int = 6;
pub const FTS_ERR: c_int = 7;
pub const FTS_F: c_int = 8;
pub const FTS_INIT: c_int = 9;
pub const FTS_NS: c_int = 10;
pub const FTS_NSOK: c_int = 11;
pub const FTS_SL: c_int = 12;
pub const FTS_SLNONE: c_int = 13;
pub const FTS_W: c_int = 14;

pub const FTS_DONTCHDIR: c_int = 0x01;
pub const FTS_SYMFOLLOW: c_int = 0x02;
pub const FTS_ISW: c_int = 0x04;

pub const FTS_AGAIN: c_int = 1;
pub const FTS_FOLLOW: c_int = 2;
pub const FTS_NOINSTR: c_int = 3;
pub const FTS_SKIP: c_int = 4;

const MAXPATHLEN: usize = 4096;
const BCHILD: c_int = 1;
const BNAMES: c_int = 2;
const BREAD: c_int = 3;

const O_RDONLY: c_int = 0x04000000;
const O_DIRECTORY: c_int = 2 << 12;
const O_CLOEXEC: c_int = 0;
const DT_DIR: u8 = 4;
const DT_UNKNOWN: u8 = 0;
const S_IFMT: c_uint = 0o170000;
const S_IFDIR: c_uint = 0o040000;
const S_IFLNK: c_uint = 0o120000;
const S_IFREG: c_uint = 0o100000;

const Compar = *const fn (*const *const FTSENT, *const *const FTSENT) callconv(.c) c_int;

pub const FTS = extern struct {
    fts_cur: ?*FTSENT,
    fts_child: ?*FTSENT,
    fts_array: ?[*]?*FTSENT,
    fts_dev: u64,
    fts_path: ?[*]u8,
    fts_rfd: c_int,
    fts_pathlen: c_uint,
    fts_nitems: c_uint,
    fts_compar: ?Compar,
    fts_options: c_int,
};

pub const FTSENT = extern struct {
    fts_cycle: ?*FTSENT,
    fts_parent: ?*FTSENT,
    fts_link: ?*FTSENT,
    fts_number: i64,
    fts_pointer: ?*anyopaque,
    fts_accpath: ?[*]u8,
    fts_path: ?[*]u8,
    fts_errno: c_int,
    fts_symfd: c_int,
    fts_pathlen: c_uint,
    fts_namelen: c_uint,
    fts_ino: u64,
    fts_dev: u64,
    fts_nlink: u64,
    fts_level: c_int,
    fts_info: c_ushort,
    fts_flags: c_ushort,
    fts_instr: c_ushort,
    fts_statp: ?*Stat,
    fts_name: [1]u8,
};

const Timespec = extern struct {
    tv_sec: i64,
    tv_nsec: c_long,
};

const Stat = extern struct {
    st_dev: u64,
    st_ino: u64,
    st_nlink: u64,
    st_mode: c_uint,
    st_uid: c_uint,
    st_gid: c_uint,
    __pad0: c_uint,
    st_rdev: u64,
    st_size: i64,
    st_blksize: c_long,
    st_blocks: i64,
    st_atim: Timespec,
    st_mtim: Timespec,
    st_ctim: Timespec,
    __reserved: [3]i64,
};

const DIR = anyopaque;
const Dirent = extern struct {
    d_ino: u64,
    d_type: u8,
    d_name: [1]u8,
};

const cextern = struct {
    extern "c" fn malloc(size: usize) ?*anyopaque;
    extern "c" fn realloc(ptr: ?*anyopaque, size: usize) ?*anyopaque;
    extern "c" fn free(ptr: ?*anyopaque) void;
    extern "c" fn qsort(base: *anyopaque, nmemb: usize, size: usize, compar: *const anyopaque) void;

    extern "c" fn opendir(path: [*:0]const u8) ?*DIR;
    extern "c" fn readdir(dir: *DIR) ?*Dirent;
    extern "c" fn closedir(dir: *DIR) c_int;
    extern "c" fn dirfd(dir: *DIR) c_int;

    extern "c" fn stat(path: [*:0]const u8, buf: *Stat) c_int;
    extern "c" fn lstat(path: [*:0]const u8, buf: *Stat) c_int;
    extern "c" fn fstat(fd: c_int, buf: *Stat) c_int;
    extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
    extern "c" fn close(fd: c_int) c_int;
};

comptime {
    _ = errno;
    if (builtin.target.isWasiLibC()) {
        symbol(&fts_open, "fts_open");
        symbol(&fts_read, "fts_read");
        symbol(&fts_children, "fts_children");
        symbol(&fts_set, "fts_set");
        symbol(&fts_close, "fts_close");

        if (@sizeOf(usize) == 4) {
            std.debug.assert(@sizeOf(FTS) == 48);
            std.debug.assert(@sizeOf(FTSENT) == 104);
        } else if (@sizeOf(usize) == 8) {
            std.debug.assert(@sizeOf(FTS) == 72);
            std.debug.assert(@sizeOf(FTSENT) == 128);
        }
    }
}

fn setErrno(e: std.c.E) void {
    std.c._errno().* = @intFromEnum(e);
}

fn isSet(sp: *const FTS, opt: c_int) bool {
    return (sp.fts_options & opt) != 0;
}

fn setOpt(sp: *FTS, opt: c_int) void {
    sp.fts_options |= opt;
}

fn clrOpt(sp: *FTS, opt: c_int) void {
    sp.fts_options &= ~opt;
}

fn entName(p: *FTSENT) [*]u8 {
    return @ptrCast(&p.fts_name[0]);
}

fn entNameConst(p: *const FTSENT) [*]const u8 {
    return @ptrCast(&p.fts_name[0]);
}

fn entNameZ(p: *FTSENT) [*:0]u8 {
    return @ptrCast(entName(p));
}

fn entNameConstZ(p: *const FTSENT) [*:0]const u8 {
    return @ptrCast(entNameConst(p));
}

fn direntName(dp: *Dirent) [*:0]const u8 {
    return @ptrCast(&dp.d_name[0]);
}

fn any(ptr: anytype) ?*anyopaque {
    if (@TypeOf(ptr) == @TypeOf(null)) return null;
    return if (ptr) |p| @ptrCast(p) else null;
}

fn pathZ(p: [*]u8) [*:0]u8 {
    return @ptrCast(p);
}

fn isDot(name: [*:0]const u8) bool {
    return name[0] == '.' and (name[1] == 0 or (name[1] == '.' and name[2] == 0));
}

fn ftsentNamelenTruncate(a: usize) c_uint {
    return @intCast(@min(a, std.math.maxInt(c_uint)));
}

fn ftsentPathlenTruncate(a: usize) c_uint {
    return @intCast(@min(a, std.math.maxInt(c_uint)));
}

fn ftsPathlenTruncate(a: usize) c_uint {
    return @intCast(@min(a, std.math.maxInt(c_uint)));
}

fn ftsNitemsTruncate(a: usize) c_uint {
    return @intCast(@min(a, std.math.maxInt(c_uint)));
}

fn nappend(p: *const FTSENT) usize {
    const path = p.fts_path.?;
    const len: usize = p.fts_pathlen;
    return if (len != 0 and path[len - 1] == '/') len - 1 else len;
}

fn copyBytes(dst: [*]u8, src: [*]const u8, len: usize) void {
    std.mem.copyForwards(u8, dst[0..len], src[0..len]);
}

fn moveBytes(dst: [*]u8, src: [*]const u8, len: usize) void {
    if (@intFromPtr(dst) <= @intFromPtr(src)) {
        std.mem.copyForwards(u8, dst[0..len], src[0..len]);
    } else {
        std.mem.copyBackwards(u8, dst[0..len], src[0..len]);
    }
}

pub fn fts_open(argv: [*:null]const ?[*:0]u8, options_arg: c_int, compar: ?Compar) callconv(.c) ?*FTS {
    var options = options_arg;
    if (comptime !have_fchdir) options |= FTS_NOCHDIR;

    if ((options & ~FTS_OPTIONMASK) != 0) {
        setErrno(.INVAL);
        return null;
    }

    const sp: *FTS = @ptrCast(@alignCast(cextern.malloc(@sizeOf(FTS)) orelse return null));
    sp.* = std.mem.zeroes(FTS);
    sp.fts_compar = compar;
    sp.fts_options = options;

    if (isSet(sp, FTS_LOGICAL)) setOpt(sp, FTS_NOCHDIR);

    if (fts_palloc(sp, @max(fts_maxarglen(argv), MAXPATHLEN)) != 0) {
        cextern.free(sp);
        return null;
    }

    const parent = fts_alloc(sp, "", 0) orelse {
        cextern.free(any(sp.fts_path));
        cextern.free(sp);
        return null;
    };
    parent.fts_level = FTS_ROOTPARENTLEVEL;

    var root: ?*FTSENT = null;
    var tmp: ?*FTSENT = null;
    var nitems: usize = 0;
    var arg_i: usize = 0;
    while (argv[arg_i]) |arg| : ({
        arg_i += 1;
        nitems += 1;
    }) {
        const len = std.mem.len(arg);
        if (len == 0) {
            setErrno(.NOENT);
            fts_lfree(root);
            fts_free(parent);
            cextern.free(any(sp.fts_path));
            cextern.free(sp);
            return null;
        }

        const p = fts_alloc(sp, arg, len) orelse {
            fts_lfree(root);
            fts_free(parent);
            cextern.free(any(sp.fts_path));
            cextern.free(sp);
            return null;
        };
        p.fts_level = FTS_ROOTLEVEL;
        p.fts_parent = parent;
        p.fts_accpath = entName(p);
        p.fts_info = fts_stat(sp, p, isSet(sp, FTS_COMFOLLOW));
        if (p.fts_info == FTS_DOT) p.fts_info = FTS_D;

        if (compar != null) {
            p.fts_link = root;
            root = p;
        } else {
            p.fts_link = null;
            if (root == null) {
                root = p;
                tmp = p;
            } else {
                tmp.?.fts_link = p;
                tmp = p;
            }
        }
    }
    if (compar != null and nitems > 1) root = fts_sort(sp, root.?, nitems);

    sp.fts_cur = fts_alloc(sp, "", 0) orelse {
        fts_lfree(root);
        fts_free(parent);
        cextern.free(any(sp.fts_path));
        cextern.free(sp);
        return null;
    };
    sp.fts_cur.?.fts_link = root;
    sp.fts_cur.?.fts_info = FTS_INIT;

    if (comptime have_fchdir) {
        if (!isSet(sp, FTS_NOCHDIR)) {
            sp.fts_rfd = cextern.open(".", O_RDONLY | O_CLOEXEC, @as(c_int, 0));
            if (sp.fts_rfd == -1) setOpt(sp, FTS_NOCHDIR);
        }
    }

    if (nitems == 0) fts_free(parent);
    return sp;
}

fn fts_load(sp: *FTS, p: *FTSENT) void {
    var len: usize = p.fts_namelen;
    p.fts_pathlen = p.fts_namelen;
    moveBytes(sp.fts_path.?, entNameConst(p), len + 1);
    if (std.mem.lastIndexOfScalar(u8, entNameConst(p)[0..len], '/')) |slash_i| {
        if (slash_i != 0 or entNameConst(p)[slash_i + 1] != 0) {
            const start = slash_i + 1;
            len = std.mem.len(@as([*:0]const u8, @ptrCast(entNameConst(p) + start)));
            moveBytes(entName(p), entNameConst(p) + start, len + 1);
            p.fts_namelen = ftsentNamelenTruncate(len);
        }
    }
    p.fts_accpath = sp.fts_path;
    p.fts_path = sp.fts_path;
    sp.fts_dev = p.fts_dev;
}

pub fn fts_close(sp: *FTS) callconv(.c) c_int {
    if (sp.fts_cur) |cur| {
        if ((cur.fts_flags & FTS_SYMFOLLOW) != 0) _ = cextern.close(cur.fts_symfd);
        var p = cur;
        while (p.fts_level >= FTS_ROOTLEVEL) {
            const freep = p;
            p = p.fts_link orelse p.fts_parent.?;
            fts_free(freep);
        }
        fts_free(p);
    }

    if (sp.fts_child) |child| fts_lfree(child);
    cextern.free(any(sp.fts_array));
    cextern.free(any(sp.fts_path));

    if (comptime have_fchdir) {}

    cextern.free(sp);
    return 0;
}

pub fn fts_read(sp: *FTS) callconv(.c) ?*FTSENT {
    if (sp.fts_cur == null or isSet(sp, FTS_STOP)) return null;

    var p = sp.fts_cur.?;
    const instr = p.fts_instr;
    p.fts_instr = FTS_NOINSTR;

    if (instr == FTS_AGAIN) {
        p.fts_info = fts_stat(sp, p, false);
        return p;
    }

    if (instr == FTS_FOLLOW and (p.fts_info == FTS_SL or p.fts_info == FTS_SLNONE)) {
        p.fts_info = fts_stat(sp, p, true);
        if (comptime have_fchdir) {
            if (p.fts_info == FTS_D and !isSet(sp, FTS_NOCHDIR)) {
                p.fts_symfd = cextern.open(".", O_RDONLY | O_CLOEXEC, @as(c_int, 0));
                if (p.fts_symfd == -1) {
                    p.fts_errno = std.c._errno().*;
                    p.fts_info = FTS_ERR;
                } else p.fts_flags |= FTS_SYMFOLLOW;
            }
        }
        return p;
    }

    if (p.fts_info == FTS_D) {
        if (instr == FTS_SKIP or (isSet(sp, FTS_XDEV) and p.fts_dev != sp.fts_dev)) {
            if ((p.fts_flags & FTS_SYMFOLLOW) != 0) _ = cextern.close(p.fts_symfd);
            if (sp.fts_child) |child| {
                fts_lfree(child);
                sp.fts_child = null;
            }
            p.fts_info = FTS_DP;
            return p;
        }

        if (sp.fts_child != null and isSet(sp, FTS_NAMEONLY)) {
            clrOpt(sp, FTS_NAMEONLY);
            fts_lfree(sp.fts_child.?);
            sp.fts_child = null;
        }

        if (sp.fts_child) |child| {
            if (fts_safe_changedir(sp, p, -1, @ptrCast(p.fts_accpath.?)) != 0) {
                p.fts_errno = std.c._errno().*;
                p.fts_flags |= FTS_DONTCHDIR;
                var q: ?*FTSENT = child;
                while (q) |node| : (q = node.fts_link) node.fts_accpath = node.fts_parent.?.fts_accpath;
            }
        } else {
            sp.fts_child = fts_build(sp, BREAD);
            if (sp.fts_child == null) {
                if (isSet(sp, FTS_STOP)) return null;
                return p;
            }
        }
        p = sp.fts_child.?;
        sp.fts_child = null;
        return returnWithName(sp, p);
    }

    while (true) {
        const tmp = p;
        sp.fts_cur = null;

        if (p.fts_link) |next_p| {
            p = next_p;
            fts_free(tmp);

            if (p.fts_level == FTS_ROOTLEVEL) {
                if (comptime have_fchdir) {}
                fts_load(sp, p);
                sp.fts_cur = p;
                return p;
            }

            if (p.fts_instr == FTS_SKIP) continue;
            if (p.fts_instr == FTS_FOLLOW) {
                p.fts_info = fts_stat(sp, p, true);
                if (comptime have_fchdir) {}
                p.fts_instr = FTS_NOINSTR;
            }

            return returnWithName(sp, p);
        }

        p = tmp.fts_parent.?;
        fts_free(tmp);

        if (p.fts_level == FTS_ROOTPARENTLEVEL) {
            fts_free(p);
            std.c._errno().* = 0;
            sp.fts_cur = null;
            return null;
        }

        sp.fts_path.?[p.fts_pathlen] = 0;

        if (comptime have_fchdir) {} else if ((p.fts_flags & FTS_DONTCHDIR) == 0 and fts_safe_changedir(sp, p.fts_parent.?, -1, "..") != 0) {
            setOpt(sp, FTS_STOP);
            return null;
        }
        p.fts_info = if (p.fts_errno != 0) FTS_ERR else FTS_DP;
        sp.fts_cur = p;
        return p;
    }
}

fn returnWithName(sp: *FTS, p: *FTSENT) *FTSENT {
    var t = sp.fts_path.? + nappend(p.fts_parent.?);
    t[0] = '/';
    t += 1;
    moveBytes(t, entNameConst(p), @as(usize, p.fts_namelen) + 1);
    sp.fts_cur = p;
    return p;
}

pub fn fts_set(sp: *FTS, p: *FTSENT, instr: c_int) callconv(.c) c_int {
    _ = sp;
    if (instr != 0 and instr != FTS_AGAIN and instr != FTS_FOLLOW and instr != FTS_NOINSTR and instr != FTS_SKIP) {
        setErrno(.INVAL);
        return 1;
    }
    p.fts_instr = @intCast(instr);
    return 0;
}

pub fn fts_children(sp: *FTS, instr_arg: c_int) callconv(.c) ?*FTSENT {
    var instr = instr_arg;
    if (instr != 0 and instr != FTS_NAMEONLY) {
        setErrno(.INVAL);
        return null;
    }

    const p = sp.fts_cur.?;
    std.c._errno().* = 0;
    if (isSet(sp, FTS_STOP)) return null;
    if (p.fts_info == FTS_INIT) return p.fts_link;
    if (p.fts_info != FTS_D) return null;

    if (sp.fts_child) |child| fts_lfree(child);

    if (instr == FTS_NAMEONLY) {
        setOpt(sp, FTS_NAMEONLY);
        instr = BNAMES;
    } else instr = BCHILD;

    if (comptime have_fchdir) {}
    sp.fts_child = fts_build(sp, instr);
    return sp.fts_child;
}

fn fts_build(sp: *FTS, type_arg: c_int) ?*FTSENT {
    const cur = sp.fts_cur.?;
    const dirp = cextern.opendir(@ptrCast(cur.fts_accpath.?)) orelse {
        if (type_arg == BREAD) {
            cur.fts_info = FTS_DNR;
            cur.fts_errno = std.c._errno().*;
        }
        return null;
    };

    var nlinks: i64 = undefined;
    var nostat: bool = undefined;
    if (type_arg == BNAMES) {
        nlinks = 0;
        nostat = true;
    } else if (isSet(sp, FTS_NOSTAT) and isSet(sp, FTS_PHYSICAL)) {
        const seedot_adjust: u64 = if (isSet(sp, FTS_SEEDOT)) 0 else 2;
        nlinks = if (cur.fts_nlink > seedot_adjust) @intCast(@min(cur.fts_nlink - seedot_adjust, @as(u64, @intCast(std.math.maxInt(i64))))) else 0;
        nostat = true;
    } else {
        nlinks = -1;
        nostat = false;
    }

    var cderrno: c_int = 0;
    var descend: bool = false;
    if (nlinks != 0 or type_arg == BREAD) {
        if (fts_safe_changedir(sp, cur, cextern.dirfd(dirp), null) != 0) {
            if (nlinks != 0 and type_arg == BREAD) cur.fts_errno = std.c._errno().*;
            cur.fts_flags |= FTS_DONTCHDIR;
            cderrno = std.c._errno().*;
        } else descend = true;
    }

    var len = nappend(cur);
    var cp: ?[*]u8 = null;
    if (isSet(sp, FTS_NOCHDIR)) {
        cp = sp.fts_path.? + len;
        cp.?[0] = '/';
        cp = cp.? + 1;
    }
    len += 1;
    var maxlen = @as(usize, sp.fts_pathlen) - len;

    const level = cur.fts_level + 1;
    var doadjust = false;
    var head: ?*FTSENT = null;
    var tail: ?*FTSENT = null;
    var nitems: usize = 0;

    while (cextern.readdir(dirp)) |dp| {
        const dname = direntName(dp);
        if (!isSet(sp, FTS_SEEDOT) and isDot(dname)) continue;

        const dnamlen = std.mem.len(dname);
        var p = fts_alloc(sp, dname, dnamlen) orelse {
            const saved_errno = std.c._errno().*;
            fts_lfree(head);
            _ = cextern.closedir(dirp);
            std.c._errno().* = saved_errno;
            cur.fts_info = FTS_ERR;
            setOpt(sp, FTS_STOP);
            return null;
        };

        if (dnamlen >= maxlen) {
            const oldaddr = sp.fts_path.?;
            if (fts_palloc(sp, dnamlen + len + 1) != 0) {
                const saved_errno = std.c._errno().*;
                fts_free(p);
                fts_lfree(head);
                _ = cextern.closedir(dirp);
                std.c._errno().* = saved_errno;
                cur.fts_info = FTS_ERR;
                setOpt(sp, FTS_STOP);
                return null;
            }
            if (oldaddr != sp.fts_path.?) {
                doadjust = true;
                if (isSet(sp, FTS_NOCHDIR)) cp = sp.fts_path.? + len;
            }
            maxlen = @as(usize, sp.fts_pathlen) - len;
        }

        p.fts_level = level;
        p.fts_pathlen = ftsentPathlenTruncate(len + dnamlen);
        p.fts_parent = cur;

        if (cderrno != 0) {
            if (nlinks != 0) {
                p.fts_info = FTS_NS;
                p.fts_errno = cderrno;
            } else p.fts_info = FTS_NSOK;
            p.fts_accpath = cur.fts_accpath;
        } else if (nlinks == 0 or (nostat and dp.d_type != DT_DIR and dp.d_type != DT_UNKNOWN)) {
            p.fts_accpath = if (isSet(sp, FTS_NOCHDIR)) p.fts_path else entName(p);
            p.fts_info = FTS_NSOK;
        } else {
            if (isSet(sp, FTS_NOCHDIR)) {
                p.fts_accpath = p.fts_path;
                moveBytes(cp.?, entNameConst(p), @as(usize, p.fts_namelen) + 1);
            } else p.fts_accpath = entName(p);
            p.fts_info = fts_stat(sp, p, false);
            if (nlinks > 0 and (p.fts_info == FTS_D or p.fts_info == FTS_DC or p.fts_info == FTS_DOT)) nlinks -= 1;
        }

        p.fts_link = null;
        if (head == null) {
            head = p;
            tail = p;
        } else {
            tail.?.fts_link = p;
            tail = p;
        }
        nitems += 1;
    }
    _ = cextern.closedir(dirp);

    if (doadjust and head != null) fts_padjust(sp, head.?);

    if (isSet(sp, FTS_NOCHDIR)) {
        var reset = cp.?;
        if (len == sp.fts_pathlen or nitems == 0) reset -= 1;
        reset[0] = 0;
    }

    if (descend and (type_arg == BCHILD or nitems == 0) and (cur.fts_level != FTS_ROOTLEVEL and fts_safe_changedir(sp, cur.fts_parent.?, -1, "..") != 0)) {
        cur.fts_info = FTS_ERR;
        setOpt(sp, FTS_STOP);
        return null;
    }

    if (nitems == 0) {
        if (type_arg == BREAD) cur.fts_info = FTS_DP;
        return null;
    }

    if (sp.fts_compar != null and nitems > 1) head = fts_sort(sp, head.?, nitems);
    return head;
}

fn fts_stat(sp: *FTS, p: *FTSENT, follow: bool) c_ushort {
    var sb: Stat = undefined;
    const sbp: *Stat = if (isSet(sp, FTS_NOSTAT)) &sb else p.fts_statp.?;

    if (isSet(sp, FTS_LOGICAL) or follow) {
        if (cextern.stat(@ptrCast(p.fts_accpath.?), sbp) != 0) {
            const saved_errno = std.c._errno().*;
            if (cextern.lstat(@ptrCast(p.fts_accpath.?), sbp) == 0) {
                std.c._errno().* = 0;
                return FTS_SLNONE;
            }
            p.fts_errno = saved_errno;
            sbp.* = std.mem.zeroes(Stat);
            return FTS_NS;
        }
    } else if (cextern.lstat(@ptrCast(p.fts_accpath.?), sbp) != 0) {
        p.fts_errno = std.c._errno().*;
        sbp.* = std.mem.zeroes(Stat);
        return FTS_NS;
    }

    if ((sbp.st_mode & S_IFMT) == S_IFDIR) {
        const dev = sbp.st_dev;
        const ino = sbp.st_ino;
        p.fts_dev = dev;
        p.fts_ino = ino;
        p.fts_nlink = sbp.st_nlink;

        if (isDot(entNameConstZ(p))) return FTS_DOT;

        var t = p.fts_parent;
        while (t) |node| : (t = node.fts_parent) {
            if (node.fts_level < FTS_ROOTLEVEL) break;
            if (ino == node.fts_ino and dev == node.fts_dev) {
                p.fts_cycle = node;
                return FTS_DC;
            }
        }
        return FTS_D;
    }
    if ((sbp.st_mode & S_IFMT) == S_IFLNK) return FTS_SL;
    if ((sbp.st_mode & S_IFMT) == S_IFREG) return FTS_F;
    return FTS_DEFAULT;
}

fn fts_sort(sp: *FTS, head_arg: *FTSENT, nitems: usize) *FTSENT {
    var head = head_arg;
    if (nitems > sp.fts_nitems) {
        const new = cextern.realloc(any(sp.fts_array), @sizeOf(?*FTSENT) * (nitems + 40)) orelse return head;
        sp.fts_array = @ptrCast(@alignCast(new));
        sp.fts_nitems = ftsNitemsTruncate(nitems + 40);
    }

    var ap = sp.fts_array.?;
    var p: ?*FTSENT = head;
    var i: usize = 0;
    while (p) |node| : ({
        p = node.fts_link;
        i += 1;
    }) ap[i] = node;

    cextern.qsort(@ptrCast(ap), nitems, @sizeOf(?*FTSENT), @ptrCast(sp.fts_compar.?));

    head = ap[0].?;
    i = 0;
    while (i + 1 < nitems) : (i += 1) ap[i].?.fts_link = ap[i + 1];
    ap[i].?.fts_link = null;
    return head;
}

fn fts_alloc(sp: *FTS, name: [*:0]const u8, namelen: usize) ?*FTSENT {
    const p: *FTSENT = @ptrCast(@alignCast(cextern.malloc(@sizeOf(FTSENT) + namelen) orelse return null));
    p.* = std.mem.zeroes(FTSENT);

    if (!isSet(sp, FTS_NOSTAT)) {
        p.fts_statp = @ptrCast(@alignCast(cextern.malloc(@sizeOf(Stat)) orelse {
            cextern.free(p);
            return null;
        }));
    } else p.fts_statp = null;

    copyBytes(entName(p), name, namelen + 1);
    p.fts_namelen = ftsentNamelenTruncate(namelen);
    p.fts_path = sp.fts_path;
    p.fts_errno = 0;
    p.fts_flags = 0;
    p.fts_instr = FTS_NOINSTR;
    p.fts_number = 0;
    p.fts_pointer = null;
    return p;
}

fn fts_free(p: *FTSENT) void {
    cextern.free(p.fts_statp);
    cextern.free(p);
}

fn fts_lfree(head_arg: ?*FTSENT) void {
    var head = head_arg;
    while (head) |p| {
        head = p.fts_link;
        fts_free(p);
    }
}

fn fts_pow2(x_arg: usize) usize {
    var x = x_arg - 1;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    if (@bitSizeOf(usize) > 32) x |= x >> 32;
    x += 1;
    return x;
}

fn fts_palloc(sp: *FTS, size_arg: usize) c_int {
    const size = fts_pow2(size_arg);
    const new = cextern.realloc(any(sp.fts_path), size) orelse return 1;
    sp.fts_path = @ptrCast(new);
    sp.fts_pathlen = ftsPathlenTruncate(size);
    return 0;
}

fn fts_padjust(sp: *FTS, head: *FTSENT) void {
    const addr = sp.fts_path.?;

    var p = sp.fts_child;
    while (p) |node| : (p = node.fts_link) adjust(addr, node);

    var q = head;
    while (q.fts_level >= FTS_ROOTLEVEL) {
        adjust(addr, q);
        q = q.fts_link orelse q.fts_parent.?;
    }
}

fn adjust(addr: [*]u8, p: *FTSENT) void {
    if (@intFromPtr(p.fts_accpath.?) != @intFromPtr(entName(p))) {
        const delta = @intFromPtr(p.fts_accpath.?) - @intFromPtr(p.fts_path.?);
        p.fts_accpath = addr + delta;
    }
    p.fts_path = addr;
}

fn fts_maxarglen(argv: [*:null]const ?[*:0]u8) usize {
    var max: usize = 0;
    var i: usize = 0;
    while (argv[i]) |arg| : (i += 1) max = @max(max, std.mem.len(arg));
    return max + 1;
}

fn fts_safe_changedir(sp: *const FTS, p: *const FTSENT, fd_arg: c_int, path: ?[*:0]const u8) c_int {
    _ = sp;
    if (comptime have_fchdir) unreachable;

    if (fd_arg < 0) {
        if (path == null) return 0;
        const zpath = path.?;
        if (std.mem.eql(u8, std.mem.span(zpath), "..")) return 0;
        const fd = cextern.open(zpath, O_RDONLY | O_CLOEXEC | O_DIRECTORY, @as(c_int, 0));
        if (fd == -1) return -1;
        const ret = verifyDirFd(fd, p);
        const saved_errno = std.c._errno().*;
        _ = cextern.close(fd);
        std.c._errno().* = saved_errno;
        return ret;
    }
    return verifyDirFd(fd_arg, p);
}

fn verifyDirFd(fd: c_int, p: *const FTSENT) c_int {
    var sb: Stat = undefined;
    if (cextern.fstat(fd, &sb) == -1) return -1;
    if (sb.st_ino != p.fts_ino or sb.st_dev != p.fts_dev) {
        setErrno(.NOENT);
        return -1;
    }
    return 0;
}

test "fts basic traversal" {
    if (!builtin.target.isWasiLibC()) return error.SkipZigTest;
}
