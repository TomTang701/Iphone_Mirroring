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

#ifndef THREADS_H
#define THREADS_H

#if defined(WIN32)
#include <time.h>
#include <winsock2.h>
#include <windows.h>
#include <errno.h>

#ifndef _TIMESPEC_DEFINED
#define _TIMESPEC_DEFINED
struct timespec {
	time_t tv_sec;
	long tv_nsec;
};
#endif

static inline void threads_get_current_timespec(struct timespec *ts)
{
	FILETIME ft;
	GetSystemTimeAsFileTime(&ft);
	unsigned long long ticks = ((unsigned long long)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
	ticks -= 116444736000000000ULL;
	ts->tv_sec = (time_t)(ticks / 10000000ULL);
	ts->tv_nsec = (long)((ticks % 10000000ULL) * 100ULL);
}

#ifndef ETIMEDOUT
#define ETIMEDOUT WSAETIMEDOUT
#endif

#define sleepms(x) Sleep(x)

typedef HANDLE thread_handle_t;

#define THREAD_RETVAL DWORD WINAPI
#define THREAD_CREATE(handle, func, arg) \
	handle = CreateThread(NULL, 0, func, arg, 0, NULL)
#define THREAD_JOIN(handle) do { WaitForSingleObject(handle, INFINITE); CloseHandle(handle); } while(0)

typedef HANDLE mutex_handle_t;

#define MUTEX_CREATE(handle) handle = CreateMutex(NULL, FALSE, NULL)
#define MUTEX_LOCK(handle) WaitForSingleObject(handle, INFINITE)
#define MUTEX_UNLOCK(handle) ReleaseMutex(handle)
#define MUTEX_DESTROY(handle) CloseHandle(handle)

typedef HANDLE cond_handle_t;

#define COND_CREATE(handle) handle = CreateEvent(NULL, TRUE, FALSE, NULL)
#define COND_SIGNAL(handle) SetEvent(handle)
#define COND_DESTROY(handle) CloseHandle(handle)

static inline int pthread_cond_timedwait(cond_handle_t *handle, mutex_handle_t *mutex, const struct timespec *abstime)
{
	DWORD timeout = INFINITE;
	if (abstime) {
		struct timespec now;
		threads_get_current_timespec(&now);
		long long diff_sec = (long long)abstime->tv_sec - (long long)now.tv_sec;
		long long diff_nsec = (long long)abstime->tv_nsec - (long long)now.tv_nsec;
		long long diff_ms = diff_sec * 1000LL + diff_nsec / 1000000LL;
		if (diff_ms < 0) {
			diff_ms = 0;
		} else if (diff_ms > (long long)INFINITE - 1) {
			diff_ms = (long long)INFINITE - 1;
		}
		timeout = (DWORD)diff_ms;
	}
	ReleaseMutex(*mutex);
	DWORD wait_result = WaitForSingleObject(*handle, timeout);
	if (wait_result == WAIT_OBJECT_0) {
		ResetEvent(*handle);
	}
	WaitForSingleObject(*mutex, INFINITE);
	if (wait_result == WAIT_TIMEOUT) {
		return ETIMEDOUT;
	}
	if (wait_result != WAIT_OBJECT_0) {
		return -1;
	}
	return 0;
}

#else /* Use pthread library */

#include <pthread.h>
#include <unistd.h>

#define sleepms(x) usleep((x)*1000)

typedef pthread_t thread_handle_t;

#define THREAD_RETVAL void *
#define THREAD_CREATE(handle, func, arg) \
	if (pthread_create(&(handle), NULL, func, arg)) handle = 0
#define THREAD_JOIN(handle) pthread_join(handle, NULL)

typedef pthread_mutex_t mutex_handle_t;

typedef pthread_cond_t cond_handle_t;

#define MUTEX_CREATE(handle) pthread_mutex_init(&(handle), NULL)
#define MUTEX_LOCK(handle) pthread_mutex_lock(&(handle))
#define MUTEX_UNLOCK(handle) pthread_mutex_unlock(&(handle))
#define MUTEX_DESTROY(handle) pthread_mutex_destroy(&(handle))

#define COND_CREATE(handle) pthread_cond_init(&(handle), NULL)
#define COND_SIGNAL(handle) pthread_cond_signal(&(handle))
#define COND_DESTROY(handle) pthread_cond_destroy(&(handle))

#endif

#endif /* THREADS_H */
