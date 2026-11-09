/*
 * Fuzz harness: LwM2M Write on the Security object (/0/0) of RIOT's wakaama client.
 *
 * stdin is the payload of a LwM2M Write request in TLV format. It is decoded with wakaama's public
 * lwm2m_data_parse() as the client does for a server's write, then handed to the Security object's
 * write callback.
 */
#include <err.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "fuzzing.h"
#include "liblwm2m.h"
#include "lwm2m_platform.h"
#include "objects/security.h"

int main(void)
{
    size_t len;
    uint8_t *input = fuzzing_read_bytes(STDIN_FILENO, &len);

    if (input == NULL) {
        errx(EXIT_FAILURE, "fuzzing_read_bytes failed");
    }

    lwm2m_platform_init();

    lwm2m_object_t *obj = lwm2m_object_security_init(NULL);
    if (obj == NULL) {
        errx(EXIT_FAILURE, "lwm2m_object_security_init failed");
    }

    lwm2m_obj_security_args_t args = {
        .server_id = 1,
        .server_uri = "coap://[fd00::1]:5683",
        .security_mode = LWM2M_SECURITY_MODE_NONE,
    };
    if (lwm2m_object_security_instance_create(&args, 0) < 0) {
        errx(EXIT_FAILURE, "lwm2m_object_security_instance_create failed");
    }

    lwm2m_uri_t uri;
    memset(&uri, 0xff, sizeof(uri));
    uri.objectId = LWM2M_SECURITY_OBJECT_ID;
    uri.instanceId = 0;

    lwm2m_data_t *data = NULL;
    int num = lwm2m_data_parse(&uri, input, len, LWM2M_CONTENT_TLV, &data);
    if (num > 0) {
        obj->writeFunc(NULL, 0, num, data, obj, LWM2M_WRITE_REPLACE_RESOURCES);
        lwm2m_data_free(num, data);
    }

    exit(EXIT_SUCCESS);
    return EXIT_SUCCESS;
}
