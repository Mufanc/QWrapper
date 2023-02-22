#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <sys/signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>

const char socket_addr[] = "/tmp/LinuxQQ-rpc.sock";
const int max_connections = 128;


[[noreturn]] void openurl() {
    int sockfd = socket(AF_UNIX, SOCK_STREAM, 0);

    sockaddr_un addr {
        .sun_family = AF_UNIX
    };
    strncpy(addr.sun_path, socket_addr, sizeof(socket_addr));

    if (access(socket_addr, F_OK) == 0) {
        unlink(socket_addr);
    }

    if (bind(sockfd, (sockaddr *) &addr, sizeof(addr)) == -1) {
        fprintf(stderr, "Failed to bind address: %s\n", socket_addr);
        exit(1);
    }

    if (listen(sockfd, max_connections) == -1) {
        perror("listen");
        exit(1);
    }

    for (;;) {
        int client = accept(sockfd, nullptr, nullptr);
        printf("daemon: new connection!\n");
        if (client == -1) {
            perror("accept");
            break;
        }

        char buffer[4096] = {0};
        size_t offset = 0;
        for (;;) {
            ssize_t count = recv(client, buffer + offset, sizeof(buffer) - offset, 0);
            if (count == -1) {
                perror("recv");
                break;
            } else if (count == 0) {
                close(client);
                break;
            }
            offset += count;
        }

        printf("xdg-open: %s\n", buffer);
        if (!fork()) {
            execlp("xdg-open", "xdg-open", buffer, nullptr);
        }
    }

    exit(1);
}

int main(int argc, char *argv[]) {
    pid_t wrapper = fork();
    if (!wrapper) {
        execl(argv[1], argv[1], "--wrap", nullptr);
        perror("exec");
        exit(1);
    }

    printf("daemon started...\n");

    pid_t server = fork();
    if (!server) openurl();

    waitpid(wrapper, nullptr, 0);
    kill(server, SIGKILL);

    return 0;
}
