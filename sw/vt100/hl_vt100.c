#define _XOPEN_SOURCE
#include <stdio.h>
#include "hl_vt100.h"

void master_write(void *user_data, void *buffer, size_t len)
{
    struct vt100_headless *this;

    this = (struct vt100_headless*)user_data;
    _write_(this->master, buffer, len);
}

struct vt100_headless *new_vt100_headless(void)
{
    struct vt100_headless* this;
    this = calloc(1, sizeof(struct vt100_headless));
    this->term = lw_terminal_vt100_init(this, lw_terminal_parser_default_unimplemented);
    this->term->master_write = master_write;
    return this;
}

void delete_vt100_headless(struct vt100_headless *this)
{
    free(this);
}

/*
static void set_non_canonical(struct vt100_headless *this, int fd)
{
    struct termios termios;

    ioctl(fd, TCGETS, &this->backup);
    ioctl(fd, TCGETS, &termios);
    termios.c_iflag |= ICANON;
    termios.c_cc[VMIN] = 1;
    termios.c_cc[VTIME] = 0;
    ioctl(fd, TCSETS, &termios);
}

static void restore_termios(struct vt100_headless *this, int fd)
{
    ioctl(fd, TCSETS, &this->backup);
}
*/

#ifndef NDEBUG
static void strdump(char *str)
{
    while (*str != '\0')
    {
        if (*str >= ' ' && *str <= '~')
            fprintf(stderr, "%c", *str);
        else
            fprintf(stderr, "\\0%o", *str);
        str += 1;
    }
    fprintf(stderr, "\n");
}
#endif

void vt100_headless_stop(struct vt100_headless *this)
{
    this->should_quit = 1;
}

/*
int vt100_headless_main_loop(struct vt100_headless *this)
{
    char buffer[4096];
    fd_set rfds;
    int retval;
    ssize_t read_size;

    while (!this->should_quit)
    {
        FD_ZERO(&rfds);
        FD_SET(this->master, &rfds);
        FD_SET(0, &rfds);
        retval = select(this->master + 1, &rfds, NULL, NULL, NULL);
        if (retval == -1)
        {
            perror("select()");
        }
        if (FD_ISSET(0, &rfds))
        {
            read_size = read(0, &buffer, 4096);
            if (read_size == -1)
            {
                perror("read");
                return EXIT_FAILURE;
            }
            buffer[read_size] = '\0';
            _write_(this->master, buffer, read_size);
        }
        if (FD_ISSET(this->master, &rfds))
        {
            read_size = read(this->master, &buffer, 4096);
            if (read_size == -1)
            {
                perror("read");
                return EXIT_FAILURE;
            }
            buffer[read_size] = '\0';
#ifndef NDEBUG
            strdump(buffer);
#endif
            lw_terminal_vt100_read_str(this->term, buffer);
            if (this->changed != NULL)
                this->changed(this);
        }
    }
    return EXIT_SUCCESS;
}
*/

char **vt100_headless_getlines(struct vt100_headless *this)
{
    return lw_terminal_vt100_getlines(this->term);
}

/*
void vt100_headless_fork(struct vt100_headless *this,
                         const char *progname,
                         char **argv)
{
    int child;
    struct winsize winsize;

    set_non_canonical(this, 0);
    winsize.ws_row = 24;
    winsize.ws_col = 80;
    child = forkpty(&this->master, NULL, NULL, NULL);
    if (child == CHILD)
    {
        setsid();
        putenv("TERM=vt100");
        execvp(progname, argv);
        return ;
    }
    else
    {
        this->term = lw_terminal_vt100_init(this, lw_terminal_parser_default_unimplemented);
        this->term->master_write = master_write;
        ioctl(this->master, TIOCSWINSZ, &winsize);
    }
    restore_termios(this, 0);
}
*/