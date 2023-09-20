#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

int main(int argc, char *argv[]) {
    openlog(NULL, 0, LOG_USER);

    // Check input argument numbers
    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguents: %d", argc);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    FILE *file = fopen(writefile, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "File could not be created: %m");
        closelog();
        return 1;
    }

    fprintf(file, "%s\n", writestr);
    fclose(file);

    syslog(LOG_DEBUG, "Writing \"%s\" to \"%s\"", writestr, writefile);

    closelog();

    return 0;
}