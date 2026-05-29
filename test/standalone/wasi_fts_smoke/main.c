#include <errno.h>
#include <fts.h>
#include <stdio.h>

int main(void) {
    char *paths[] = { ".", 0 };
    FTS *fts = fts_open(paths, FTS_PHYSICAL | FTS_NOCHDIR, 0);
    if (!fts) {
        perror("fts_open");
        return 1;
    }

    int saw_entry = 0;
    FTSENT *ent;
    while ((ent = fts_read(fts)) != 0) {
        if (ent->fts_info == FTS_ERR || ent->fts_info == FTS_DNR || ent->fts_info == FTS_NS) {
            errno = ent->fts_errno;
            perror(ent->fts_path);
            (void)fts_close(fts);
            return 1;
        }
        saw_entry = 1;
    }

    if (fts_close(fts) != 0) {
        perror("fts_close");
        return 1;
    }
    return saw_entry ? 0 : 1;
}
