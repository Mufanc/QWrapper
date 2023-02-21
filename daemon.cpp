#include <cstdio>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

const char socket_addr[] = "/tmp/LinuxQQ-rpc.sock";
const int max_connections = 128;

int main() {
    printf("daemon started...\n");

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
        return 1;
    }

    if (listen(sockfd, max_connections) == -1) {
        perror("listen");
        return 1;
    }

    for (;;) {
        int client = accept(sockfd, nullptr, nullptr);
        printf("daemon: new connection!\n", client);
        if (client == -1) break;

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
}
