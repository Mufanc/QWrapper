#include <iostream>
#include <regex>
#include <dlfcn.h>
#define execvp __execvp
#include <sys/unistd.h>
#undef execvp
#include <sys/socket.h>
#include <sys/un.h>

const char socket_addr[] = "/tmp/LinuxQQ-rpc.sock";

extern "C" int execvp(const char *path, char *argv[]);
typedef decltype(&execvp) execvp_t;
execvp_t execvp_old = nullptr;


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

std::string url_decode(const std::string &str) {
    std::stringstream builder;

    char state = 'N', escape;
    for (auto ch : str) {
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

    return builder.str();
}

void send_msg(std::string str) {
    int sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sockfd == -1) {
        perror("socket");
        return;
    }

    sockaddr_un addr {
        .sun_family = AF_UNIX
    };
    strncpy(addr.sun_path, socket_addr, sizeof(socket_addr));

    if (connect(sockfd, (sockaddr *) &addr, sizeof(addr)) == -1) {
        perror("connect");
        return;
    }

    int offset = 0, count;
    while ((count = send(sockfd, str.c_str() + offset, str.length() - offset, 0))) {
        if (count == -1) {
            perror("send");
        }
        offset += count;
        if (offset >= str.length()) break;
    }

    close(sockfd);
}

void xdg_open(const char *path, char *argv[]) {
    const std::regex pattern(R"((?:https?://)?c.pc.qq.com/([^?#]*)\.html(?:\?([^#]*))?(?:#.*)?)");
    const std::regex queries(R"(([^&=]+)=([^&=]+))");

    std::smatch result;
    std::string url = argv[1];

    if (std::regex_match(url, result, pattern) && result.size() >= 2) {
        std::string pctype = result[1];

        std::string key = "#";
        if (pctype == "middlem") {
            key = "pfurl";
        } else if (pctype == "ios") {
            key = "url";
        } else {
            printf("Warning: unknown pctype `%s`\n", pctype.c_str());
        }

        std::string query = result[2];

        std::sregex_iterator it(query.begin(), query.end(), queries);
        std::sregex_iterator end;

        for (; it != end; it++) {
            if (it->str(1) != key) continue;

            std::string redir_url = url_decode(it->str(2));

            printf("Redirect to: %s\n", redir_url.c_str());
            argv[1] = (char *) redir_url.c_str();

            send_msg(redir_url);
            exit(0);
        }
    }

    send_msg(url);
    exit(0);
}

extern "C"
int execvp(const char *path, char *argv[]) {
    static void *handle = nullptr;
    if (!handle) {
        handle = dlopen("libc.so.6", RTLD_LAZY);
        execvp_old = (execvp_t) dlsym(handle, "execvp");
    }

    bool trace_exec = (getenv("TRACE_EXEC") != nullptr);
    int argc = 0;
    if (trace_exec) printf("execvp: ");
    for (char **ptr = argv; *ptr; ptr++) {
        argc++;
        if (!trace_exec) continue;
        if (ptr == argv) {
            printf("%s\n", *ptr);
        } else {
            printf("    %s\n", *ptr);
        }
    }
    if (trace_exec) printf("\n");

    if (std::string_view(argv[0]) == "xdg-open" && argc >= 2) {
        xdg_open(path, argv);
    }

    return execvp_old(path, argv);
}
