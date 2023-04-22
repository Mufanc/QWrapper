#include <cstdio>
#include <cstdint>
#include <cstring>
#include <sys/mman.h>

#define HIDE_NAME "__patch__/libhook.so"

extern "C"
void hide_soname() {
    FILE *maps = fopen("/proc/self/maps", "r");

    void *start, *end;
    char permission[8], name[256];

    while (fscanf(maps, "%p-%p %s %*s %*s %*s %[^\n]", &start, &end, permission, name) != EOF) {
        if (strstr(name, HIDE_NAME) == nullptr) continue;

        printf("hide soname: %p-%p %s %s\n", start, end, permission, name);

        size_t length = (uintptr_t) end - (uintptr_t) start;

        void *backup = mmap(nullptr, length, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
        memcpy(backup, start, length);

        munmap(start, length);

        int pro = 0;
        if (permission[0] == 'r') pro |= PROT_READ;
        if (permission[1] == 'w') pro |= PROT_WRITE;
        if (permission[2] == 'x') pro |= PROT_EXEC;

        mmap(start, length, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
        memcpy(start, backup, length);
        mprotect(start, length, pro);

        munmap(backup, length);
    }
}
