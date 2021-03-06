#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "util.h"

char *
startsWith(const char *conts, const char *contd)
{
	char *ptr = strstr(conts, contd);

	if (strlen(contd) > strlen(conts))
		return NULL;

	return ptr && (*contd == *conts) ? ptr : NULL;
}

bool
isNumber(char *str)
{
	while(*str)
		if (!(isdigit(*str++)))
			return false;
	return true;
}

/* Ref: http://man7.org/tlpi/code/online/dist/sockets/read_line.c.html */
ssize_t
readLine(int fd, void *buffer, size_t sz)
{
	ssize_t numRead;
	size_t totRead;
	char *buff;
	char ch;

	if (sz <= 0 || buffer == NULL) {
		errno = EINVAL;
		return -1;
	}

	buff = buffer;
	totRead = 0;

	while(true) {
		numRead = read(fd, &ch, 1);

		if (numRead == -1) {
			if (errno == EINTR)
			continue;
			else
			return -1;
		}
		else if (numRead == 0) {
			if (totRead == 0)
			return 0;
			else
			break;
		}
		else {
			if (totRead < sz - 1) {
				totRead++;
				*buff++ = ch;
			}
			if (ch == '\n')
			break;
		}
	}
	*buff = '\0';
	return totRead;
}

/* Ref: http://www.paulgriffiths.net/program/c/srcs/echoservsrc.html */
ssize_t
writeLine(int sockd, const void *vptr, size_t n) {
	size_t nleft;
	ssize_t nwritten;
	const char *buffer;

	buffer = vptr;
	nleft  = n;

	while (nleft > 0) {
		if ((nwritten = write(sockd, buffer, nleft)) <= 0)
			if (errno == EINTR)
				nwritten = 0;
		nleft  -= nwritten;
		buffer += nwritten;
	}

	return n;
}

void
/*
 * Print message to stderr and exit
 */
fatal (char *fmt, ...) {
	va_list args;
	va_start(args, fmt);
	vfprintf(stderr, fmt, args);
	va_end(args);
	exit(EXIT_FAILURE);
}
