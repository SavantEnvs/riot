/*
 * ethos serial-line harness: feeds stdin to ethos's own frame decoder (_serial_handle_byte), the way
 * main() feeds it what it read() from the serial device (an MCU's byte stream, an untrusted peer).
 * The loop below is main()'s read loop minus the fd side effects of dispatching a completed frame
 * (writes to the tap device, stdout and the serial line, `ip neigh flush`).
 * ETHOS_FRAME_DUMP prints each completed frame instead: the oracle mayhem/test.sh asserts on.
 */
#define main ethos_main
#include "../dist/tools/ethos/ethos.c"
#undef main

int main(void)
{
    char inbuf[MTU];
    serial_t serial = {0};
    ssize_t n;

    while ((n = read(STDIN_FILENO, inbuf, sizeof(inbuf))) > 0) {
        char *ptr = inbuf;
        while (n--) {
            size_t res = _serial_handle_byte(&serial, *ptr++);
            if (res) {
#ifdef ETHOS_FRAME_DUMP
                printf("type=%d len=%zu hex=", serial.frametype, serial.framebytes);
                for (size_t i = 0; i < serial.framebytes; i++) {
                    printf("%02x", (unsigned char)serial.frame[i]);
                }
                printf("\n");
#endif
                memset(&serial, '\0', sizeof(serial));
            }
        }
    }
    return 0;
}
