#include <iostream>
#include <regex>
#include <string_view>
#include <dlfcn.h>

int ctoi(char ch) {
    if ('0' <= ch && ch <= '9') {
        return ch - '0';
    } else if ('A' <= ch && ch <= 'F') {
        return ch - 'A' + 10;
    } else if ('a' <= ch && ch <= 'f') {
        return ch - 'a' + 10;
    } else {
        return -1;
    }
}

extern "C"
int execvp(const char *path, char *argv[]) {
    typedef decltype(&execvp) Self;

    static void *handle = nullptr;
    static Self backup_old = nullptr;

    if (!handle) {
        handle = dlopen("libc.so.6", RTLD_LAZY);
        backup_old = (Self) dlsym(handle, "execvp");
    }

    int argc = 0;
    printf("execvp: ");
    for (char **ptr = argv; *ptr; ptr++) {
        if (ptr == argv) {
            printf("%s\n", *ptr);
        } else {
            printf("    %s\n", *ptr);
        }
        argc++;
    }
    printf("\n");

    if (std::string_view(argv[0]) == "xdg-open" && argc >= 2) {
        const std::regex pattern(R"((?:https?://)?c.pc.qq.com/(?:[^?#]*)(?:\?([^#]*))?(?:#.*)?)");
        const std::regex queries(R"(([^&=]+)=([^&=]+))");

        std::smatch result;
        std::string url = argv[1];

        if (std::regex_match(url, result, pattern) && result.size() >= 2) {
            std::string query = result[1];

            std::sregex_iterator it(query.begin(), query.end(), queries);
            std::sregex_iterator end;

            for (;it != end; it++) {
                if (it->size() < 3) continue;
                if (it->str(1) != "pfurl") continue;

                std::stringstream builder;

                char state = 'N', escape;
                for (auto ch : it->str(2)) {
                    switch (state) {
                        default: {  // Normal
                            if (ch == '%') {
                                state = '1';
                                escape = 0;
                            } else {
                                builder << ch;
                            }
                            break;
                        }
                        case '1': {  // escape 1
                            escape = ctoi(ch);
                            state = '2';
                            break;
                        }
                        case '2': {  // escape
                            builder << (char) ((escape << 4) | ctoi(ch));
                            state = 'N';
                            break;
                        }
                    }
                }

                std::string pfurl = builder.str();
                
                printf("Redirect: %s\n", pfurl.c_str());
                argv[1] = (char *) pfurl.c_str();

                return backup_old(path, argv);
            }
        }
        argv[1] = nullptr;
    }

    return backup_old(path, argv);
}
