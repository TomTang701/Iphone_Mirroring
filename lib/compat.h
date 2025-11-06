/**
 *  Copyright (C) 2011-2012  Juho Vähä-Herttua
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 */

#ifndef COMPAT_H
#define COMPAT_H

#if defined(WIN32)
#include <ws2tcpip.h>
#include <windows.h>
#include <time.h>
#include <stdint.h>
#ifndef snprintf
#define snprintf _snprintf
#endif
#ifndef CLOCK_REALTIME
#define CLOCK_REALTIME 0
#endif

static inline void compat_filetime_to_timespec(struct timespec *ts)
{
	FILETIME ft;
	GetSystemTimeAsFileTime(&ft);
	uint64_t ticks = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
	ticks -= 116444736000000000ULL; /* 100ns intervals between 1601 and 1970 */
	ts->tv_sec = (time_t)(ticks / 10000000ULL);
	ts->tv_nsec = (long)((ticks % 10000000ULL) * 100ULL);
}

static inline int compat_clock_gettime(int type, struct timespec *ts)
{
	(void)type;
	if (!ts) {
		return -1;
	}
	compat_filetime_to_timespec(ts);
	return 0;
}

static inline int compat_gettimeofday(struct timeval *tv, void *tz)
{
	(void)tz;
	if (!tv) {
		return -1;
	}
	struct timespec ts;
	compat_clock_gettime(CLOCK_REALTIME, &ts);
	tv->tv_sec = (long)ts.tv_sec;
	tv->tv_usec = (long)(ts.tv_nsec / 1000L);
	return 0;
}

#ifndef clock_gettime
#define clock_gettime compat_clock_gettime
#endif

#ifndef gettimeofday
#define gettimeofday compat_gettimeofday
#endif

#else
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <netdb.h>
#include <pthread.h>
#endif

#include "memalign.h"
#include "sockets.h"
#include "threads.h"

#endif
