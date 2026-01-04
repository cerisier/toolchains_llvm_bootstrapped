#include <errno.h>
#include <locale.h>
#include <pwd.h>
#include <stddef.h>
#include <time.h>
#include <wchar.h>

locale_t newlocale(int mask, const char *locname, locale_t base) {
  (void)mask;
  (void)locname;
  (void)base;
  errno = ENOSYS;
  return (locale_t)0;
}

locale_t uselocale(locale_t loc) {
  (void)loc;
  return (locale_t)0;
}

void freelocale(locale_t loc) {
  (void)loc;
}

size_t wcsnrtombs(char *dst, const wchar_t **src, size_t wn, size_t n,
                  mbstate_t *ps) {
  (void)dst;
  (void)src;
  (void)wn;
  (void)n;
  (void)ps;
  errno = ENOSYS;
  return (size_t)-1;
}

size_t mbsnrtowcs(wchar_t *dst, const char **src, size_t nms, size_t len,
                  mbstate_t *ps) {
  (void)dst;
  (void)src;
  (void)nms;
  (void)len;
  (void)ps;
  errno = ENOSYS;
  return (size_t)-1;
}

size_t mbsrtowcs(wchar_t *dst, const char **src, size_t len, mbstate_t *ps) {
  (void)dst;
  (void)src;
  (void)len;
  (void)ps;
  errno = ENOSYS;
  return (size_t)-1;
}

size_t wcrtomb(char *s, wchar_t wc, mbstate_t *ps) {
  (void)s;
  (void)wc;
  (void)ps;
  errno = ENOSYS;
  return (size_t)-1;
}

size_t mbrtowc(wchar_t *pwc, const char *s, size_t n, mbstate_t *ps) {
  (void)pwc;
  (void)s;
  (void)n;
  (void)ps;
  errno = ENOSYS;
  return (size_t)-1;
}

int mbtowc(wchar_t *pwc, const char *s, size_t n) {
  (void)pwc;
  (void)s;
  (void)n;
  errno = ENOSYS;
  return -1;
}

size_t mbrlen(const char *s, size_t n, mbstate_t *ps) {
  (void)s;
  (void)n;
  (void)ps;
  errno = ENOSYS;
  return (size_t)-1;
}

size_t strftime_l(char *s, size_t max, const char *format, const struct tm *tm,
                  locale_t loc) {
  (void)s;
  (void)max;
  (void)format;
  (void)tm;
  (void)loc;
  errno = ENOSYS;
  return 0;
}

int getpwuid_r(uid_t uid, struct passwd *pwd, char *buf, size_t buflen,
               struct passwd **result) {
  (void)uid;
  (void)pwd;
  (void)buf;
  (void)buflen;
  if (result) *result = NULL;
  return ENOSYS;
}

int getpwnam_r(const char *name, struct passwd *pwd, char *buf, size_t buflen,
               struct passwd **result) {
  (void)name;
  (void)pwd;
  (void)buf;
  (void)buflen;
  if (result) *result = NULL;
  return ENOSYS;
}

size_t strftime(char *s, size_t max, const char *format, const struct tm *tm) {
  (void)s;
  (void)max;
  (void)format;
  (void)tm;
  errno = ENOSYS;
  return 0;
}
