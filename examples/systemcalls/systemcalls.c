#include "systemcalls.h"
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{

/*
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/
    int result = system(cmd);
    if(result==0)
        return true;
    else
        return false;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];

/*
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/

    int status = -1;
    fflush(stdout);
    pid_t pid = fork();
    if (pid == -1) {
        printf("Error creating a child process:%s\n", strerror(errno));
        va_end(args);
        return false;
    } 
    if (pid==0) {
        printf("Child process created successfully\n");
        if (execv(command[0], command) == -1)
        {
            printf("Error executing execv: %s\n", strerror(errno));
            va_end(args);
            exit(-1);
        }
    } else {
        if (wait(&status) == -1) {
            printf("Error executing wait: %s\n", strerror(errno));
            va_end(args);
            return false;
        }
        if (WIFEXITED(status))
        {
            if (0 == WEXITSTATUS(status))
            {
                va_end(args);
                return true;
            }
            else
            {
                va_end(args);
                return false;
            }
        }
    }

    va_end(args);

    return true;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];


/*
 *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
 *   redirect standard out to a file specified by outputfile.
 *   The rest of the behaviour is same as do_exec()
 *
*/
    int status = -1;
    int fd = open(outputfile, O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if (fd==-1)
    {
        printf("Error opening file:%s\n", strerror(errno));
        va_end(args);
        return false;
    }
    fflush(stdout);
    pid_t pid = fork();
    if (pid==-1) {
        printf("Error creating a child process:%s\n", strerror(errno));
        close(fd);
        va_end(args);
        return false;
    }
    if (pid==0) {
        printf("Child process created successfully\n");
        if (dup2(fd, 1)==-1) {
            printf("Error executing dup2: %s\n", strerror(errno));
            close(fd);
            va_end(args);
            return false;
        } if (execv(command[0], command) == -1) {
            printf("Error executing execv: %s\n", strerror(errno));
            close(fd);
            va_end(args);
            return false;
        }
    } else {
        close(fd);
        if (wait(&status) == -1) {
            printf("Error executing wait: %s\n", strerror(errno));
            va_end(args);
            return false;
        }
        if (WIFEXITED(status)) {
            va_end(args);   
            if (WEXITSTATUS(status) == 0) {
                printf("Child process exited with status %d\n", WEXITSTATUS(status));
                return true;
            } else {
                printf("Child process did not exit normally\n");
                return false;
            }
        }
    }
    va_end(args);

    return true;
}
